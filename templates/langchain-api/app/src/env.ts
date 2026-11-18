// Runtime environment: injected paths plus settable tunables. The app
// reads env only, never files, and uses injected paths verbatim.

export interface AppEnv {
  dbPath: string;
  socketPath: string;
  deploymentId: string;
  template: string;
  templateVersion: string;
  logLevel: string;
  llmBaseUrl: string;
  llmApiKey: string;
  llmModel: string;
}

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`missing required env ${name}`);
  return v;
}

export function loadEnv(): AppEnv {
  return {
    dbPath: required("DB_PATH"),
    socketPath: required("SOCKET_PATH"),
    deploymentId: required("DEPLOYMENT_ID"),
    template: required("TEMPLATE"),
    templateVersion: required("TEMPLATE_VERSION"),
    logLevel: process.env["LOG_LEVEL"] ?? "info",
    llmBaseUrl: process.env["LLM_BASE_URL"] ?? "https://api.openai.com/v1",
    llmApiKey: process.env["LLM_API_KEY"] ?? "",
    llmModel: process.env["LLM_MODEL"] ?? "gpt-4o-mini",
  };
}

export function log(level: string, msg: string, extra?: unknown): void {
  const line = extra === undefined ? msg : `${msg} ${JSON.stringify(extra)}`;
  if (level === "debug") console.debug(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}
