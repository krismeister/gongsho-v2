import { configureApiClients } from './api';
import { loadConfig, type UiConfig } from './config';

// Async boot gate: load config, configure clients, then render.
// main.tsx awaits this before mounting anything.
export interface Boot {
  config: UiConfig;
}

export async function boot(): Promise<Boot> {
  const config = await loadConfig();
  configureApiClients(config);
  // Wired APIs: import each generated client here and point it at its
  // same-origin path before returning, e.g.
  //   import { client as shopApi } from '../client/acme_shop_api-1/client.gen';
  //   shopApi.setConfig({ baseUrl: config.apis['acme_shop_api-1'] });
  // (imports hoist to the top of this file; see README "Wiring an API".)
  return { config };
}
