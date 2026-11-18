// SQLite access over node:sqlite. Schema is owned by migrations/ (applied
// by the harness migrate verb, never here); this module only reads and
// writes rows.

import { DatabaseSync } from "node:sqlite";
import { createHash } from "node:crypto";

export interface PlanVersionRow {
  session_id: string;
  version: number;
  body: string;
  plan_hash: string;
  status: string;
  created_at: string;
}

export function openDb(path: string): DatabaseSync {
  return new DatabaseSync(path);
}

export function ensureSession(db: DatabaseSync, id: string): void {
  db.prepare("INSERT OR IGNORE INTO planning_sessions (id) VALUES (?)").run(id);
}

export function sessionExists(db: DatabaseSync, id: string): boolean {
  const row = db.prepare("SELECT id FROM planning_sessions WHERE id = ?").get(id);
  return row !== undefined;
}

export function latestDraft(db: DatabaseSync, sessionId: string): PlanVersionRow | null {
  const row = db
    .prepare(
      "SELECT session_id, version, body, plan_hash, status, created_at FROM plan_versions WHERE session_id = ? ORDER BY version DESC LIMIT 1",
    )
    .get(sessionId) as PlanVersionRow | undefined;
  return row ?? null;
}

export function insertDraft(
  db: DatabaseSync,
  sessionId: string,
  body: string,
): { version: number; hash: string } {
  const versionRow = db
    .prepare("SELECT COALESCE(MAX(version), 0) + 1 AS v FROM plan_versions WHERE session_id = ?")
    .get(sessionId) as { v: number };
  const version = versionRow.v;
  const hash = createHash("sha256").update(body, "utf8").digest("hex");
  db.prepare(
    "INSERT INTO plan_versions (session_id, version, body, plan_hash, status) VALUES (?, ?, ?, ?, 'draft')",
  ).run(sessionId, version, body, hash);
  return { version, hash };
}

export function setDraftStatus(
  db: DatabaseSync,
  sessionId: string,
  version: number,
  status: "approved" | "rejected",
): void {
  db.prepare("UPDATE plan_versions SET status = ? WHERE session_id = ? AND version = ?").run(
    status,
    sessionId,
    version,
  );
}

export function planHash(body: string): string {
  return createHash("sha256").update(body, "utf8").digest("hex");
}
