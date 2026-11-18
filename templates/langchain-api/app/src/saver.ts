// SQLite checkpointer for LangGraph, mirroring MemorySaver semantics over
// the app database (tables owned by migrations/). Checkpoints serialize
// through the saver serde; blobs store as base64 text.

import type { DatabaseSync } from "node:sqlite";
import {
  BaseCheckpointSaver,
  WRITES_IDX_MAP,
  compareWritesSortKeys,
  getCheckpointId,
  writesSortKey,
  type ChannelVersions,
  type Checkpoint,
  type CheckpointListOptions,
  type CheckpointMetadata,
  type CheckpointTuple,
  type PendingWrite,
} from "@langchain/langgraph-checkpoint";
import type { RunnableConfig } from "@langchain/core/runnables";

const POLLUTION_KEYS = new Set(["__proto__", "constructor", "prototype"]);

function assertSafeKey(field: string, value: unknown, allowEmpty = false): void {
  if (typeof value !== "string" || (!allowEmpty && value === "")) {
    throw new Error(`invalid configurable value for key "${field}"`);
  }
  if (POLLUTION_KEYS.has(value)) {
    throw new Error(`reserved configurable value for key "${field}"`);
  }
}

function threadOf(config: RunnableConfig): string {
  const threadId = config.configurable?.["thread_id"];
  assertSafeKey("thread_id", threadId);
  return threadId as string;
}

function nsOf(config: RunnableConfig): string {
  const ns = config.configurable?.["checkpoint_ns"] ?? "";
  assertSafeKey("checkpoint_ns", ns, true);
  return ns as string;
}

type WriteRecord = { taskId: string; channel: string; value: string; taskPath: string; idx: number };

export class SqliteSaver extends BaseCheckpointSaver {
  private db: DatabaseSync;

  constructor(db: DatabaseSync) {
    super();
    this.db = db;
  }

  private orderedWrites(threadId: string, ns: string, checkpointId: string): WriteRecord[] {
    const rows = this.db
      .prepare(
        "SELECT task_id AS taskId, channel, value_type AS valueType, value, task_path AS taskPath, idx FROM graph_checkpoint_writes WHERE thread_id = ? AND checkpoint_ns = ? AND checkpoint_id = ?",
      )
      .all(threadId, ns, checkpointId) as Array<{
      taskId: string;
      channel: string;
      valueType: string;
      value: string;
      taskPath: string;
      idx: number;
    }>;
    const keyed = rows.map((r) => ({
      key: writesSortKey(r.taskPath ?? "", r.taskId, r.idx),
      row: r,
    }));
    keyed.sort((a, b) => compareWritesSortKeys(a.key, b.key));
    return keyed.map(({ row }) => ({
      taskId: row.taskId,
      channel: row.channel,
      value: row.value,
      taskPath: row.taskPath,
      idx: row.idx,
    }));
  }

  private async deserializeWrites(records: WriteRecord[]): Promise<[string, string, unknown][]> {
    return Promise.all(
      records.map(async (r) => {
        const buf = Buffer.from(r.value, "base64");
        return [r.taskId, r.channel, await this.serde.loadsTyped("json", new Uint8Array(buf))] as [
          string,
          string,
          unknown,
        ];
      }),
    );
  }

  private async toTuple(
    _config: RunnableConfig,
    threadId: string,
    ns: string,
    checkpointId: string,
    checkpointBlob: string,
    metadataBlob: string,
    parentCheckpointId: string | null,
  ): Promise<CheckpointTuple> {
    const checkpoint = (await this.serde.loadsTyped(
      "json",
      new Uint8Array(Buffer.from(checkpointBlob, "base64")),
    )) as Checkpoint;
    const metadata = (await this.serde.loadsTyped(
      "json",
      new Uint8Array(Buffer.from(metadataBlob, "base64")),
    )) as CheckpointMetadata;
    const pendingWrites = await this.deserializeWrites(
      this.orderedWrites(threadId, ns, checkpointId),
    );
    const tuple: CheckpointTuple = {
      config: { configurable: { thread_id: threadId, checkpoint_ns: ns, checkpoint_id: checkpointId } },
      checkpoint,
      metadata,
      pendingWrites,
    };
    if (parentCheckpointId) {
      tuple.parentConfig = {
        configurable: { thread_id: threadId, checkpoint_ns: ns, checkpoint_id: parentCheckpointId },
      };
    }
    return tuple;
  }

  async getTuple(config: RunnableConfig): Promise<CheckpointTuple | undefined> {
    const threadId = threadOf(config);
    const ns = nsOf(config);
    const checkpointId = getCheckpointId(config);
    if (checkpointId) {
      assertSafeKey("checkpoint_id", checkpointId);
      const row = this.db
        .prepare(
          "SELECT checkpoint, metadata, parent_checkpoint_id AS parentId FROM graph_checkpoints WHERE thread_id = ? AND checkpoint_ns = ? AND checkpoint_id = ?",
        )
        .get(threadId, ns, checkpointId) as
        | { checkpoint: string; metadata: string; parentId: string | null }
        | undefined;
      if (!row) return undefined;
      return this.toTuple(config, threadId, ns, checkpointId, row.checkpoint, row.metadata, row.parentId);
    }
    const row = this.db
      .prepare(
        "SELECT checkpoint_id AS id, checkpoint, metadata, parent_checkpoint_id AS parentId FROM graph_checkpoints WHERE thread_id = ? AND checkpoint_ns = ? ORDER BY checkpoint_id DESC LIMIT 1",
      )
      .get(threadId, ns) as
      | { id: string; checkpoint: string; metadata: string; parentId: string | null }
      | undefined;
    if (!row) return undefined;
    return this.toTuple(config, threadId, ns, row.id, row.checkpoint, row.metadata, row.parentId);
  }

  async *list(
    config: RunnableConfig,
    options?: CheckpointListOptions,
  ): AsyncGenerator<CheckpointTuple> {
    const { before, limit, filter } = options ?? {};
    const wanted = config.configurable?.["thread_id"] as string | undefined;
    if (wanted !== undefined) assertSafeKey("thread_id", wanted);
    const ns = (config.configurable?.["checkpoint_ns"] as string | undefined) ?? undefined;
    const onlyId = config.configurable?.["checkpoint_id"] as string | undefined;
    const threadIds = wanted ? [wanted] : (this.db.prepare("SELECT DISTINCT thread_id AS id FROM graph_checkpoints").all() as Array<{ id: string }>).map((r) => r.id);
    let remaining = limit;
    for (const threadId of threadIds) {
      const namespaces = (
        this.db.prepare("SELECT DISTINCT checkpoint_ns AS ns FROM graph_checkpoints WHERE thread_id = ?").all(threadId) as Array<{ ns: string }>
      ).map((r) => r.ns);
      for (const checkpointNs of namespaces) {
        if (ns !== undefined && checkpointNs !== ns) continue;
        const rows = this.db
          .prepare(
            "SELECT checkpoint_id AS id, checkpoint, metadata, parent_checkpoint_id AS parentId FROM graph_checkpoints WHERE thread_id = ? AND checkpoint_ns = ? ORDER BY checkpoint_id DESC",
          )
          .all(threadId, checkpointNs) as Array<{
          id: string;
          checkpoint: string;
          metadata: string;
          parentId: string | null;
        }>;
        for (const r of rows) {
          if (onlyId && r.id !== onlyId) continue;
          const beforeId = (before?.configurable?.["checkpoint_id"] as string | undefined) ?? undefined;
          if (beforeId && r.id >= beforeId) continue;
          const metadata = (await this.serde.loadsTyped(
            "json",
            new Uint8Array(Buffer.from(r.metadata, "base64")),
          )) as CheckpointMetadata;
          if (filter && !Object.entries(filter).every(([k, v]) => (metadata as Record<string, unknown>)[k] === v)) continue;
          if (remaining !== undefined) {
            if (remaining <= 0) return;
            remaining -= 1;
          }
          yield this.toTuple(config, threadId, checkpointNs, r.id, r.checkpoint, r.metadata, r.parentId);
        }
      }
    }
  }

  async put(
    config: RunnableConfig,
    checkpoint: Checkpoint,
    metadata: CheckpointMetadata,
    _newVersions: ChannelVersions,
  ): Promise<RunnableConfig> {
    const threadId = threadOf(config);
    const ns = nsOf(config);
    assertSafeKey("checkpoint_id", checkpoint.id);
    const [checkpointType, checkpointBytes] = await this.serde.dumpsTyped(checkpoint);
    const [metadataType, metadataBytes] = await this.serde.dumpsTyped(metadata);
    const parentId = (config.configurable?.["checkpoint_id"] as string | undefined) ?? null;
    this.db
      .prepare(
        "INSERT OR REPLACE INTO graph_checkpoints (thread_id, checkpoint_ns, checkpoint_id, parent_checkpoint_id, checkpoint_type, checkpoint, metadata_type, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      )
      .run(
        threadId,
        ns,
        checkpoint.id,
        parentId,
        checkpointType,
        Buffer.from(checkpointBytes).toString("base64"),
        metadataType,
        Buffer.from(metadataBytes).toString("base64"),
      );
    return { configurable: { thread_id: threadId, checkpoint_ns: ns, checkpoint_id: checkpoint.id } };
  }

  async putWrites(
    config: RunnableConfig,
    writes: PendingWrite[],
    taskId: string,
    taskPath?: string,
  ): Promise<void> {
    const threadId = threadOf(config);
    const ns = nsOf(config);
    const checkpointId = config.configurable?.["checkpoint_id"] as string | undefined;
    if (!checkpointId) throw new Error("putWrites is missing checkpoint_id");
    assertSafeKey("checkpoint_id", checkpointId);
    assertSafeKey("task_id", taskId);
    const path = taskPath ?? "";
    for (let i = 0; i < writes.length; i++) {
      const [channel, value] = writes[i] as [string, unknown];
      const [valueType, valueBytes] = await this.serde.dumpsTyped(value);
      const idx = WRITES_IDX_MAP[channel] ?? i;
      const exists = this.db
        .prepare(
          "SELECT 1 FROM graph_checkpoint_writes WHERE thread_id = ? AND checkpoint_ns = ? AND checkpoint_id = ? AND task_id = ? AND idx = ?",
        )
        .get(threadId, ns, checkpointId, taskId, idx);
      if (idx >= 0 && exists) continue;
      this.db
        .prepare(
          "INSERT OR REPLACE INTO graph_checkpoint_writes (thread_id, checkpoint_ns, checkpoint_id, task_id, idx, channel, value_type, value, task_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .run(
          threadId,
          ns,
          checkpointId,
          taskId,
          idx,
          channel,
          valueType,
          Buffer.from(valueBytes).toString("base64"),
          path,
        );
    }
  }

  async deleteThread(threadId: string): Promise<void> {
    assertSafeKey("thread_id", threadId);
    this.db.prepare("DELETE FROM graph_checkpoint_writes WHERE thread_id = ?").run(threadId);
    this.db.prepare("DELETE FROM graph_checkpoints WHERE thread_id = ?").run(threadId);
  }
}
