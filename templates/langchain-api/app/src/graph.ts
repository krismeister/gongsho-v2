// Planning graph: converse until the model emits a plan, persist the
// draft version, then pause on interrupt() for per-version approval.
// Threads are planning sessions (thread_id == session id); the SQLite
// saver makes pauses durable across restarts.

import type { DatabaseSync } from "node:sqlite";
import type { RunnableConfig } from "@langchain/core/runnables";
import { AIMessage, type BaseMessage } from "@langchain/core/messages";
import {
  Annotation,
  END,
  START,
  StateGraph,
  addMessages,
  interrupt,
} from "@langchain/langgraph";
import { insertDraft, setDraftStatus } from "./db.js";
import { generateReply, type ModelConfig, type Turn } from "./model.js";
import { SqliteSaver } from "./saver.js";

export interface PlanBody {
  name: string;
  template: string;
  goals: string[];
}

export type SessionStatus = "clarifying" | "awaiting_approval" | "approved";

const PlanningAnnotation = Annotation.Root({
  messages: Annotation<BaseMessage[]>({ reducer: addMessages, default: () => [] }),
  draft: Annotation<PlanBody | null>({
    reducer: (_left, right) => right ?? null,
    default: () => null,
  }),
  draftVersion: Annotation<number | null>({
    reducer: (_left, right) => right ?? null,
    default: () => null,
  }),
  status: Annotation<SessionStatus>({
    reducer: (_left, right) => right,
    default: () => "clarifying" as SessionStatus,
  }),
});

export interface GraphDeps {
  db: DatabaseSync;
  model: ModelConfig;
}

function toTurns(messages: BaseMessage[]): Turn[] {
  return messages.map((m) => ({
    role: m.getType() === "human" ? ("user" as const) : ("assistant" as const),
    text: typeof m.content === "string" ? m.content : JSON.stringify(m.content),
  }));
}

function parsePlan(reply: string): PlanBody | null {
  if (!reply.startsWith("PLAN:")) return null;
  try {
    const raw = JSON.parse(reply.slice("PLAN:".length).trim()) as Partial<PlanBody>;
    if (typeof raw.name !== "string" || typeof raw.template !== "string") return null;
    const goals = Array.isArray(raw.goals) ? raw.goals.filter((g): g is string => typeof g === "string") : [];
    return { name: raw.name, template: raw.template, goals };
  } catch {
    return null;
  }
}

export function buildGraph(deps: GraphDeps) {
  const { db, model } = deps;

  async function converse(state: typeof PlanningAnnotation.State) {
    const reply = await generateReply(toTurns(state.messages), model);
    const draft = parsePlan(reply);
    if (draft) {
      return { messages: [new AIMessage(reply)], draft, status: "awaiting_approval" as SessionStatus };
    }
    return { messages: [new AIMessage(reply)], status: "clarifying" as SessionStatus };
  }

  // Side effects live here, before any interrupt: this node runs exactly
  // once per draft, so a resume never inserts twice.
  async function record(state: typeof PlanningAnnotation.State, config: RunnableConfig) {
    const sessionId = config.configurable?.["thread_id"] as string;
    const { version } = insertDraft(db, sessionId, JSON.stringify(state.draft));
    return { draftVersion: version };
  }

  // The gate holds no side effects before interrupt(): resume re-runs only
  // this node, applying the verdict to the version record() stored.
  async function gate(state: typeof PlanningAnnotation.State, config: RunnableConfig) {
    const sessionId = config.configurable?.["thread_id"] as string;
    const version = state.draftVersion;
    if (version === null) return { status: "clarifying" as SessionStatus };
    const decision = interrupt({ version, draft: state.draft }) as
      | { approved?: boolean; version?: number }
      | undefined;
    if (decision?.approved === true && decision.version === version) {
      setDraftStatus(db, sessionId, version, "approved");
      return { status: "approved" as SessionStatus };
    }
    setDraftStatus(db, sessionId, version, "rejected");
    return { status: "clarifying" as SessionStatus };
  }

  const graph = new StateGraph(PlanningAnnotation)
    .addNode("converse", converse)
    .addNode("record", record)
    .addNode("gate", gate)
    .addEdge(START, "converse")
    .addConditionalEdges("converse", (state) =>
      state.status === "awaiting_approval" ? "record" : END,
    )
    .addEdge("record", "gate")
    .addEdge("gate", END)
    .compile({ checkpointer: new SqliteSaver(db) });

  return graph;
}

export type PlanningGraph = ReturnType<typeof buildGraph>;
