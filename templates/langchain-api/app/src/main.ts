// Entrypoint: serves the planning API on the injected unix socket.

import { loadEnv, log } from "./env.js";
import { createApp } from "./server.js";

const env = loadEnv();
const { server } = createApp();

server.listen(env.socketPath, () => {
  log("info", `planning api listening on ${env.socketPath} (${env.deploymentId})`);
});
server.on("error", (err) => {
  log("warn", "server error", { error: String(err) });
  process.exitCode = 1;
});
