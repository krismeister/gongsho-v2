// HTTP over the unix socket (Caddy strips the deployment prefix, so the
// app sees clean paths). Routes:
//   GET  /healthz, /info, /openapi.json (platform contract)
//   POST /sessions (open a planning session)
//   POST /sessions/:id/turns {message} (clarify loop)
//   POST /sessions/:id/approvals {version, approved} (per-version gate)
//   GET  /sessions/:id/drafts/latest (read the frozen artifact)

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { HumanMessage } from "@langchain/core/messages";
import { Command } from "@langchain/langgraph";
import {
  ensureSession,
  latestDraft,
  openDb,
  sessionExists,
} from "./db.js";
import { loadEnv, log } from "./env.js";
import { buildGraph, type PlanningGraph } from "./graph.js";

const HERE = dirname(fileURLToPath(import.meta.url));
// dist/*.js at runtime (rootDir src), src/*.ts under type stripping:
// openapi.json lives in gen/ next to src/ and dist/ either way.
const SPEC_CANDIDATES = [join(HERE, "..", "gen", "openapi.json"), "/nonexistent"];

function loadSpec(): string {
  for (const p of SPEC_CANDIDATES) {
    try {
      return readFileSync(p, "utf8");
    } catch {
      // next
    }
  }
  return '{"openapi":"3.0.3","info":{"title":"planning api","version":"0.0.0"},"paths":{}}';
}

const MAX_BODY = 1_048_576;

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error("body too large"));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function send(res: ServerResponse, code: number, body: unknown): void {
  const text = typeof body === "string" ? body : JSON.stringify(body);
  res.writeHead(code, { "content-type": "application/json" });
  res.end(text);
}

function lastAssistantText(messages: Array<{ getType(): string; content: unknown }>): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i]!;
    if (m.getType() !== "human") {
      return typeof m.content === "string" ? m.content : JSON.stringify(m.content);
    }
  }
  return "";
}

export function createApp(): { server: ReturnType<typeof createServer>; graph: PlanningGraph } {
  const env = loadEnv();
  const db = openDb(env.dbPath);
  const graph = buildGraph({
    db,
    model: { baseUrl: env.llmBaseUrl, apiKey: env.llmApiKey, model: env.llmModel },
  });
  const spec = loadSpec();

  const server = createServer((req, res) => {
    void (async () => {
      const url = new URL(req.url ?? "/", "http://localhost");
      const method = req.method ?? "GET";
      const path = url.pathname;

      if (method === "GET" && path === "/healthz") return send(res, 200, { status: "ok" });
      if (method === "GET" && path === "/info") {
        return send(res, 200, {
          id: env.deploymentId,
          template: env.template,
          templateVersion: env.templateVersion,
        });
      }
      if (method === "GET" && path === "/openapi.json") {
        res.writeHead(200, { "content-type": "application/json" });
        return res.end(spec);
      }

      if (method === "POST" && path === "/sessions") {
        const id = randomUUID();
        ensureSession(db, id);
        return send(res, 200, { id });
      }

      const turnMatch = path.match(/^\/sessions\/([^/]+)\/turns$/);
      if (method === "POST" && turnMatch) {
        const id = turnMatch[1]!;
        if (!sessionExists(db, id)) return send(res, 404, { error: "unknown session" });
        const pending = latestDraft(db, id);
        if (pending && pending.status === "draft") {
          return send(res, 409, {
            error: `draft v${pending.version} is awaiting approval; approve or reject it first`,
            version: pending.version,
          });
        }
        let parsed: unknown;
        try {
          parsed = JSON.parse(await readBody(req));
        } catch {
          return send(res, 400, { error: "invalid JSON body" });
        }
        const message = (parsed as { message?: unknown }).message;
        if (typeof message !== "string" || !message.trim()) {
          return send(res, 400, { error: "message must be a non-empty string" });
        }
        try {
          let status = "clarifying";
          const config = { configurable: { thread_id: id } };
          for await (const chunk of await graph.stream(
            { messages: [new HumanMessage(message)] },
            config,
          )) {
            if ("__interrupt__" in chunk && Array.isArray(chunk.__interrupt__)) {
              const first = chunk.__interrupt__[0] as { value?: { version?: number } };
              const state = await graph.getState(config);
              const draft = (state.values as { draft?: unknown }).draft ?? null;
              return send(res, 200, {
                status: "awaiting_approval",
                version: first.value?.version ?? null,
                reply: lastAssistantText(state.values.messages as never),
                draft,
              });
            }
          }
          const state = await graph.getState(config);
          status = String((state.values as { status?: unknown }).status ?? "clarifying");
          return send(res, 200, {
            status,
            reply: lastAssistantText(state.values.messages as never),
            version: null as number | null,
            draft: null as unknown,
          });
        } catch (err) {
          log("warn", "turn failed", { error: String(err) });
          return send(res, 502, { error: "model turn failed" });
        }
      }

      const approveMatch = path.match(/^\/sessions\/([^/]+)\/approvals$/);
      if (method === "POST" && approveMatch) {
        const id = approveMatch[1]!;
        if (!sessionExists(db, id)) return send(res, 404, { error: "unknown session" });
        let parsed: unknown;
        try {
          parsed = JSON.parse(await readBody(req));
        } catch {
          return send(res, 400, { error: "invalid JSON body" });
        }
        const { version, approved } = parsed as { version?: unknown; approved?: unknown };
        if (typeof version !== "number" || typeof approved !== "boolean") {
          return send(res, 400, { error: "need numeric version and boolean approved" });
        }
        const pending = latestDraft(db, id);
        if (!pending || pending.status !== "draft" || pending.version !== version) {
          return send(res, 409, { error: "no matching draft awaiting approval" });
        }
        try {
          const out = (await graph.invoke(new Command({ resume: { approved, version } }), {
            configurable: { thread_id: id },
          })) as { status?: unknown };
          const row = latestDraft(db, id);
          return send(res, 200, {
            status: String(out.status ?? row?.status ?? "unknown"),
            version: row?.version ?? null,
            hash: row?.plan_hash ?? null,
            plan: row ? JSON.parse(row.body) : null,
          });
        } catch (err) {
          log("warn", "approval failed", { error: String(err) });
          return send(res, 502, { error: "approval resume failed" });
        }
      }

      const draftMatch = path.match(/^\/sessions\/([^/]+)\/drafts\/latest$/);
      if (method === "GET" && draftMatch) {
        const id = draftMatch[1]!;
        if (!sessionExists(db, id)) return send(res, 404, { error: "unknown session" });
        const row = latestDraft(db, id);
        if (!row) return send(res, 404, { error: "no drafts yet" });
        return send(res, 200, {
          version: row.version,
          hash: row.plan_hash,
          status: row.status,
          plan: JSON.parse(row.body),
          created_at: row.created_at,
        });
      }

      return send(res, 404, { error: "not found" });
    })().catch((err: unknown) => {
      log("warn", "request failed", { error: String(err) });
      if (!res.headersSent) send(res, 500, { error: "internal error" });
      else res.end();
    });
  });

  return { server, graph };
}
