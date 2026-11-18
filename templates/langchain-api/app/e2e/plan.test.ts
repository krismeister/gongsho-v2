// Template e2e: clarify loop, per-version approval, frozen artifact.
// Runs against the dev route (E2E_BASE_URL/<path>) with the stub model
// (no LLM_API_KEY), so no network or key is needed.

import { describe, it, before } from "node:test";
import assert from "node:assert/strict";

function baseURL(): string {
  const found = Object.entries(process.env).filter(([k]) => k.startsWith("E2E_APP_")).map(([, v]) => (v ?? "").replace(/\/$/, ""));
  if (found.length === 1 && found[0]) return found[0] as string;
  const base = (process.env["E2E_BASE_URL"] ?? "").replace(/\/$/, "");
  assert.ok(base, "set E2E_BASE_URL or exactly one E2E_APP_<ID> variable");
  assert.ok(found.length <= 1, "multiple E2E_APP_* variables set; test one deployment per run");
  return base;
}

const BASE = baseURL();

async function api(method: string, path: string, body?: unknown): Promise<{ code: number; json: unknown }> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {"content-type": "application/json"},
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = (await res.json()) as unknown;
  return {code: res.status, json};
}

function field<T>(obj: unknown, name: string): T {
  assert.ok(typeof obj === "object" && obj !== null, "response is an object");
  assert.ok(name in obj, `response has ${name}`);
  return (obj as Record<string, unknown>)[name] as T;
}

describe("planning api", () => {
  before(() => {
    assert.ok(BASE, "base URL resolves");
  });

  it("serves the platform contract", async () => {
    const health = await api("GET", "/healthz");
    assert.equal(health.code, 200);
    assert.deepEqual(health.json, {status: "ok"});

    const info = await api("GET", "/info");
    assert.equal(info.code, 200);
    assert.match(field<string>(info.json, "id"), /^[a-z0-9-]+_[a-z0-9-]+_[a-z0-9-]+$/);
    assert.equal(field<string>(info.json, "template"), "langchain-api");
    assert.match(field<string>(info.json, "templateVersion"), /^\d+\.\d+$/);

    const spec = await api("GET", "/openapi.json");
    assert.equal(spec.code, 200);
    assert.ok("/sessions" in field<Record<string, unknown>>(spec.json, "paths"));
  });

  it("clarifies, drafts, approves, and freezes the plan", async () => {
    const opened = await api("POST", "/sessions");
    assert.equal(opened.code, 200);
    const session = field<string>(opened.json, "id");
    assert.ok(session.length > 0);

    const turn1 = await api("POST", `/sessions/${session}/turns`, {message: "name: acme-shop"});
    assert.equal(turn1.code, 200);
    assert.equal(field<string>(turn1.json, "status"), "clarifying");
    assert.ok(field<string>(turn1.json, "reply").length > 0);

    const turn2 = await api("POST", `/sessions/${session}/turns`, {message: "template: goa-api"});
    assert.equal(turn2.code, 200);
    assert.equal(field<string>(turn2.json, "status"), "awaiting_approval");
    const version = field<number>(turn2.json, "version");
    assert.equal(version, 1);
    const draft = field<Record<string, unknown>>(turn2.json, "draft");
    assert.equal(draft["name"], "acme-shop");
    assert.equal(draft["template"], "goa-api");

    const blocked = await api("POST", `/sessions/${session}/turns`, {message: "actually change it"});
    assert.equal(blocked.code, 409);

    const approval = await api("POST", `/sessions/${session}/approvals`, {version, approved: true});
    assert.equal(approval.code, 200);
    assert.equal(field<string>(approval.json, "status"), "approved");
    const hash = field<string>(approval.json, "hash");
    assert.match(hash, /^[0-9a-f]{64}$/);

    const frozen = await api("GET", `/sessions/${session}/drafts/latest`);
    assert.equal(frozen.code, 200);
    assert.equal(field<number>(frozen.json, "version"), version);
    assert.equal(field<string>(frozen.json, "hash"), hash);
    assert.equal(field<string>(frozen.json, "status"), "approved");

    const again = await api("POST", `/sessions/${session}/approvals`, {version, approved: true});
    assert.equal(again.code, 409);
  });

  it("rejects unknown sessions and bad bodies", async () => {
    const missing = await api("POST", "/sessions/nope/turns", {message: "hi"});
    assert.equal(missing.code, 404);
    const opened = await api("POST", "/sessions");
    const session = field<string>(opened.json, "id");
    const bad = await api("POST", `/sessions/${session}/turns`, {message: ""});
    assert.equal(bad.code, 400);
  });
});
