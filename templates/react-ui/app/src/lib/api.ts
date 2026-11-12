import { createClient, type Client } from '@hey-api/client-fetch';
import type { UiConfig } from './config';

// Per-API client registry. Clients are configured once at boot
// (see lib/boot.ts) via setConfig({ baseUrl }) from gen-config.json.
// baseUrl values are absolute same-origin paths, so no CORS
// configuration exists anywhere.
const registry = new Map<string, Client>();

export function configureApiClients(config: UiConfig): void {
  registry.clear();
  for (const [id, path] of Object.entries(config.apis)) {
    const client = createClient();
    client.setConfig({ baseUrl: path });
    registry.set(id, client);
  }
}

export function getApiClient(id: string): Client {
  const client = registry.get(id);
  if (client === undefined) throw new Error(`no configured client for API ${id}`);
  return client;
}

export async function fetchHealth(id: string): Promise<boolean> {
  try {
    const { response } = await getApiClient(id).get({ url: '/healthz' });
    return response.ok;
  } catch {
    return false;
  }
}
