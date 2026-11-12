import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { boot } from './lib/boot';
import './index.css';

const root = document.getElementById('root');
if (root === null) throw new Error('missing #root element');

// Async boot gate: load gen-config.json, setConfig per API, then render.
// Nothing mounts before boot resolves; boot failure renders loudly.
boot().then(
  ({ config }) => {
    createRoot(root).render(
      <StrictMode>
        <App config={config} />
      </StrictMode>,
    );
  },
  (err: unknown) => {
    const message = err instanceof Error ? err.message : String(err);
    createRoot(root).render(
      <StrictMode>
        <main>
          <h1>Gongsho UI</h1>
          <p role="alert">Failed to boot: {message}</p>
        </main>
      </StrictMode>,
    );
  },
);
