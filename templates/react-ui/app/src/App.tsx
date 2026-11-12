import { useEffect, useState } from 'react';
import { fetchHealth } from './lib/api';
import type { UiConfig } from './lib/config';

type ApiStatus = 'checking' | 'ok' | 'down';

// Rendered only after the boot gate (lib/boot.ts) loads config and
// configures API clients, so config is a prop, never a fetch here.
export default function App({ config }: { config: UiConfig }) {
  const [statuses, setStatuses] = useState<Record<string, ApiStatus>>({});

  useEffect(() => {
    let cancelled = false;
    const ids = Object.keys(config.apis);
    setStatuses(Object.fromEntries(ids.map((id) => [id, 'checking' as const])));
    void Promise.all(
      ids.map(async (id) => {
        const ok = await fetchHealth(id);
        if (!cancelled) {
          setStatuses((prev) => ({ ...prev, [id]: ok ? 'ok' : 'down' }));
        }
      }),
    );
    return () => {
      cancelled = true;
    };
  }, [config]);

  const ids = Object.keys(config.apis);
  return (
    <main>
      <h1>Gongsho UI</h1>
      <div data-testid="api-status">
        {ids.length === 0 ? (
          <p>No APIs configured yet. Wire one via refresh-spec, then rebuild.</p>
        ) : (
          <ul>
            {ids.map((id) => (
              <li key={id}>
                <code>{id}</code> <code>{config.apis[id]}</code> — {statuses[id] ?? 'checking'}
              </li>
            ))}
          </ul>
        )}
      </div>
    </main>
  );
}
