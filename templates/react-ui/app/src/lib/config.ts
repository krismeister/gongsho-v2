// Runtime config loader. gen-config.json is served beside the bundle (deploy
// writes it from the deployment pin) and read relative to the build base,
// so no API address is ever baked in at build time. The gen- prefix keeps
// this harness-owned file clear of any app-owned config.json.
export interface UiConfig {
  /** API deployment id (acme_shop_api-1) -> absolute same-origin path (/acme/shop/api-1). */
  apis: Record<string, string>;
}

function isUiConfig(data: unknown): data is UiConfig {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return false;
  const apis = (data as { apis?: unknown }).apis;
  if (typeof apis !== 'object' || apis === null || Array.isArray(apis)) return false;
  return Object.values(apis).every(
    (path): path is string => typeof path === 'string' && path.startsWith('/'),
  );
}

export async function loadConfig(): Promise<UiConfig> {
  const url = `${import.meta.env.BASE_URL}gen-config.json`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`runtime config missing: GET ${url} -> HTTP ${res.status}`);
  }
  const data: unknown = await res.json();
  if (!isUiConfig(data)) {
    throw new Error(`runtime config malformed: ${url} must be {"apis": {<id>: "</path>"}}`);
  }
  return data;
}
