// Model calls behind one function. The graph speaks a tiny text protocol:
// replies are either `QUESTION: <text>` or `PLAN: <json>`. With no
// LLM_API_KEY the deterministic offline stub answers instead, so the
// template scaffolds, builds, and passes e2e with no key and no network.

export interface Turn {
  role: "user" | "assistant";
  text: string;
}

export interface ModelConfig {
  baseUrl: string;
  apiKey: string;
  model: string;
}

const SYSTEM_PROMPT = [
  "You help a user plan a gongsho project. Ask ONE clarifying question",
  "at a time until you know the project name and which template to use",
  "(goa-api, langchain-api, or react-ui).",
  "",
  "Reply format, exactly one of:",
  '- QUESTION: <your single clarifying question>',
  '- PLAN: <a JSON object {"name": string, "template": string, "goals": string[]}>',
  "",
  "Output a PLAN only when both name and template are known. Output",
  "nothing but the single line.",
].join("\n");

function stubReply(turns: Turn[]): string {
  const userText = turns
    .filter((t) => t.role === "user")
    .map((t) => t.text)
    .join("\n");
  const name = userText.match(/name:\s*([A-Za-z0-9][A-Za-z0-9_-]*)/i)?.[1];
  const template = userText.match(/template:\s*(goa-api|langchain-api|react-ui)/i)?.[1];
  if (!name) return "QUESTION: What should the project be called? Reply with `name: <project-name>`.";
  if (!template)
    return "QUESTION: Which template should it use (goa-api, langchain-api, or react-ui)? Reply with `template: <name>`.";
  const plan = { name, template, goals: [`Scaffold ${name} from ${template}`, "Run check plus e2e green"] };
  return `PLAN: ${JSON.stringify(plan)}`;
}

export async function generateReply(turns: Turn[], cfg: ModelConfig): Promise<string> {
  if (!cfg.apiKey) return stubReply(turns);
  const messages = [{ role: "system", content: SYSTEM_PROMPT }];
  for (const t of turns) {
    messages.push({ role: t.role === "user" ? "user" : "assistant", content: t.text });
  }
  const res = await fetch(`${cfg.baseUrl.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${cfg.apiKey}` },
    body: JSON.stringify({ model: cfg.model, messages, temperature: 0 }),
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok) throw new Error(`model request failed with status ${res.status}`);
  const data = (await res.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const text = data.choices?.[0]?.message?.content?.trim();
  if (!text) throw new Error("model returned no content");
  return text.split("\n")[0] ?? "";
}
