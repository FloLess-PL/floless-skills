---
name: floless-think-nodes
description: Configure FloLess Think Nodes — LLM-per-execution nodes for prompts, classification, summarization, extraction, and translation. Use when authoring or updating Think Node configuration, writing prompt templates, selecting models and temperature, managing I/O schemas, or using the update-think-node PATCH semantics. Also covers the Smart vs Think decision rule: prefer Smart Nodes (deterministic C#) when logic is static.
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read Write
---

# floless-think-nodes

A Think Node is an LLM-per-execution workflow node. Every time the workflow runs, the Think Node sends a prompt to an LLM and injects the model's response into the data pipeline — no C# code required. Think Nodes are the right choice for tasks that require natural language understanding: classification, summarization, extraction from unstructured text, translation, and similar reasoning tasks.

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

## When to use this skill

Load this skill when you need to:

- Add a Think Node to a workflow (with `NodeType: "ThinkNode"` in the workflow JSON)
- Update a Think Node's prompt, model, temperature, or schema using `floless workflow update-think-node`
- Choose between a Smart Node and a Think Node for a given task
- Write or refine a PromptTemplate with upstream variable references
- Configure I/O schemas (`InputSchemaJson`, `OutputSchemaJson`) for structured LLM output
- Enable caching, set token budgets, or change response format

For deterministic C# logic, see the `floless-smart-nodes` skill instead.

## Smart Node vs Think Node decision

> **Prefer Smart Nodes when logic is static. Prefer Think Nodes only when LLM reasoning is essential.**

| Signal | Use Smart Node | Use Think Node |
|--------|---------------|----------------|
| Output is deterministic | Yes | No |
| Rule can be unit-tested | Yes | No |
| Input is unstructured text | No | Yes |
| Task requires NLU / reasoning | No | Yes |
| Cost matters at scale | Yes (zero LLM cost) | Consider caching |

**Decision rule of thumb:** "Can I write `expect(fn(input)).toBe(output)` deterministically for every case?" If yes → Smart Node (zero runtime LLM cost). If no → Think Node.

**Examples:**

- Formatting a number as currency → Smart Node
- Classifying a support message into 5 predefined categories → Think Node
- Extracting name/email/phone from a paragraph → Think Node
- Converting a string to uppercase → Smart Node
- Summarizing a Tekla model change log → Think Node
- Routing based on a boolean flag → Smart Node

Always reach for a Smart Node first. Only escalate to a Think Node when the task is genuinely beyond deterministic code.

## Think Node properties

All properties below are the **VM property names** — the names accepted by `floless workflow update-think-node`. The serialized `.flo` format uses `ThinkNode*`-prefixed names internally, but the CLI always takes the VM names.

### PromptTemplate (required)

The prompt sent to the LLM at execution time. Must contain at minimum a reference to at least one upstream value. Use `{{variable}}` double-brace syntax to reference upstream data (this is the runtime engine's template syntax — double braces are evaluated at execution time, not authoring time).

Examples of runtime variable references inside a PromptTemplate value:
- `{{trigger.cellValue}}` — value from the trigger that started the workflow
- `{{action1.result}}` — output from the node named `action1`
- `{{nodes.myNode.output.text}}` — named node output field

> **Note on brace syntax:** In this skill's prose, `{variable}` (single brace) is used to denote a placeholder you replace with a real value (e.g., replace `{nodeId}` with an actual GUID). Inside the actual PromptTemplate string sent to the CLI, use `{{variable}}` (double brace) — that is the runtime engine's syntax evaluated at workflow execution.

### SystemPrompt (optional)

An LLM role/persona prompt prepended before the PromptTemplate. Pass `""` (empty string) to clear an existing system prompt.

Example: `"You are a concise technical writer. Respond only in plain text."`

### SelectedModel (optional)

The model ID to use for this Think Node (e.g., `claude-sonnet-4-20250514`). When omitted or `null`, the desktop uses the user's configured default model, resolved via `AiModelEscalation.ResolveAutoStartModel`.

Cannot be cleared with empty string — the CLI will return `invalid_empty_string`. Omit the `--model` option to leave the current model unchanged.

Common values:
- `claude-sonnet-4-20250514` — balanced performance
- `claude-haiku-4-20250514` — fast and cheap; ideal for classification with caching
- `claude-opus-4-20250514` — highest capability; use for complex extraction

### Temperature (optional)

Float from `0.0` to `1.0` controlling output randomness:

| Value | Preset | Best for |
|-------|--------|----------|
| `0.1` | Precise | Classification, extraction, structured JSON output |
| `0.5` | Balanced | General summarization |
| `0.9` | Creative | Translation with stylistic freedom, creative writing |

Cannot be cleared — omit `--temperature` to leave unchanged.

### ResponseFormat (optional)

Controls how the LLM formats its response:

- `json` — Instructs the model to output valid JSON. Pair with `OutputSchemaJson` for structured output.
- `text` — Plain text (default)
- `markdown` — Markdown-formatted response

Cannot be cleared with empty string. Omit `--response-format` to leave unchanged.

### OutputSchemaJson (optional)

A JSON Schema (draft-07) describing the expected LLM output structure. Only meaningful when `ResponseFormat=json`. Pass `""` to clear.

Example:
```json
{"type":"object","properties":{"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"string"}}},"required":["summary","key_points"]}
```

### InputSchemaJson (optional)

A JSON Schema validated against the upstream data before the LLM call. If validation fails, the node errors with `input_schema_violation` before calling the LLM — saving tokens. Pass `""` to clear.

### IsCachingEnabled (optional)

Boolean (`true`/`false`). When `true`, the CLI caches LLM responses keyed on the exact prompt content + input values. Subsequent executions with identical inputs skip the LLM call entirely. Cannot be cleared — omit `--caching` to leave unchanged.

Enable when: prompts are deterministic and inputs repeat frequently.
Disable when: prompts reference time-sensitive data (timestamps, "today's date", live prices).

### MaxInputTokens / MaxOutputTokens (optional)

Integer token budget controls:

- `MaxInputTokens` — Preflight check before sending to the LLM. If the rendered prompt exceeds this, the node errors with `input_token_budget_exceeded` without making an LLM call.
- `MaxOutputTokens` — Passed as `max_tokens` to the LLM API. Hard ceiling on response length.

Cannot be cleared — omit the option to leave unchanged.

## Variable templating: `{variable}` vs `{{variable}}`

This skill uses two brace conventions:

| Convention | Where | Meaning |
|------------|-------|---------|
| `{variable}` (single brace) | Prose, CLI option examples | Placeholder you replace with a real value |
| `{{variable}}` (double brace) | Inside PromptTemplate string values | Runtime template syntax — evaluated by the workflow engine at execution |

**Example showing both in context:**

In prose: "Replace `{nodeId}` with the GUID from `floless workflow nodes --json`."

In the actual CLI command (the PromptTemplate value uses double braces):
```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template "Summarize this document: {{action1.result}}" \
  --json
```

Here `{nodeId}` is a placeholder you replace; `{{action1.result}}` is a runtime reference the engine evaluates.

## Updating Think Nodes in loaded workflows — `floless workflow update-think-node`

Use `update-think-node` to modify a Think Node's configuration in the currently loaded workflow. This command follows **PATCH semantics**:

> - **Omit an option** → that field is left unchanged (current value preserved)
> - **Pass empty string** for a nullable string field → field is cleared to null
> - **Pass a value** → field is updated to that value

For non-nullable string fields (`SelectedModel`, `ResponseFormat`) and numeric/bool fields (`Temperature`, `IsCachingEnabled`, `MaxInputTokens`, `MaxOutputTokens`): empty string is rejected with `invalid_empty_string`. Omit the option to leave those fields unchanged.

**Full example — update prompt, temperature, and output schema:**

```bash
floless workflow update-think-node \
  --workflow current \
  --node abc-123-def-456 \
  --prompt-template "Summarize this: {{input.text}}" \
  --temperature 0.3 \
  --response-format json \
  --output-schema-json '{"type":"object","properties":{"summary":{"type":"string"}}}' \
  --json
```

**Option-to-property mapping (CLI kebab-case → VM property name):**

| CLI Option | VM Property | Clearable? |
|------------|-------------|-----------|
| `--prompt-template` | `PromptTemplate` | Yes (pass `""`) |
| `--system-prompt` | `SystemPrompt` | Yes (pass `""`) |
| `--model` | `SelectedModel` | No (omit to preserve) |
| `--temperature` | `Temperature` | No (omit to preserve) |
| `--response-format` | `ResponseFormat` | No (omit to preserve) |
| `--output-schema-json` | `OutputSchemaJson` | Yes (pass `""`) |
| `--input-schema-json` | `InputSchemaJson` | Yes (pass `""`) |
| `--caching` | `IsCachingEnabled` | No (omit to preserve) |
| `--max-input-tokens` | `MaxInputTokens` | No (omit to preserve) |
| `--max-output-tokens` | `MaxOutputTokens` | No (omit to preserve) |

**Success envelope:**
```json
{"success": true, "data": {"nodeId": "abc-123-def-456", "updated": true}}
```

## Discovery — templates and schema

List the Think Node template to inspect the canonical JSON structure:

```bash
# Retrieve Think Node template (also accepts --type prompt as alias)
floless templates --type think --json
```

Inspect the full ThinkNode schema:

```bash
floless schema --type thinknode --json
```

Use the schema output to verify property names and types before constructing workflow JSON manually.

## Worked example: updating a summarization Think Node

**Step 1 — List nodes in the loaded workflow to find the target node ID:**

```bash
floless workflow nodes --workflow current --json
# Response: {"success":true,"data":[{"id":"b9f1e2a3-...","type":"ThinkNode","display":"Summarize Report",...}]}
```

**Step 2 — Inspect the current Think Node configuration:**

```bash
floless workflow node-context --workflow current --node b9f1e2a3-0000-0000-0000-000000000001 --json
# Response includes PromptTemplate, SelectedModel, Temperature, ResponseFormat, etc.
```

**Step 3 — Update the prompt template and temperature (PATCH — other fields unchanged):**

```bash
floless workflow update-think-node \
  --workflow current \
  --node b9f1e2a3-0000-0000-0000-000000000001 \
  --prompt-template "Summarize the following report in 3 bullet points:\n\n{{action1.result}}" \
  --temperature 0.3 \
  --json
# Response: {"success":true,"data":{"nodeId":"b9f1e2a3-0000-0000-0000-000000000001","updated":true}}
```

Only `PromptTemplate` and `Temperature` changed. `SelectedModel`, `SystemPrompt`, `ResponseFormat`, and all schema fields remain exactly as they were.

## Common gotchas

1. **Using `{{variable}}` in prose or option help.** Use `{variable}` (single brace) in prose to indicate a placeholder you substitute. Reserve `{{variable}}` for actual PromptTemplate string values where the runtime engine will evaluate them. Mixing conventions causes confusion and breaks accuracy scripts.

2. **Using serialization-prefixed names instead of VM property names.** The `.flo` file format prefixes Think Node properties with `ThinkNode` internally (e.g., the serialized JSON has `ThinkNode`-prefixed keys). The CLI's `update-think-node` command does NOT accept these prefixed names. Always use the VM property names: `PromptTemplate`, `SystemPrompt`, `SelectedModel`, etc. Passing a serialization-prefixed key silently does nothing — the server ignores unknown fields. Phase 69.1 D-10 is the authoritative source for this rule.

3. **Passing empty string to a non-nullable field.** `SelectedModel`, `ResponseFormat`, `Temperature`, `IsCachingEnabled`, `MaxInputTokens`, and `MaxOutputTokens` reject empty strings with `errorCode: "invalid_empty_string"`. Omit the option entirely to leave those fields unchanged.

4. **Forgetting `OutputSchemaJson` when `ResponseFormat=json`.** Setting `--response-format json` without a corresponding `--output-schema-json` causes the LLM to output JSON with an unpredictable structure. Always pair `ResponseFormat=json` with a concrete `OutputSchemaJson`.

5. **Checking `success` for compilation result.** `success:true` means the API call succeeded — it does NOT mean the LLM produced valid output. For structured JSON output, validate `data.output` against your expected schema after the workflow runs.

6. **Omitting `--json`.** Without `--json`, the CLI outputs human-readable text. AI terminals must always use `--json` to get the parseable Stripe-style envelope.

## Progressive disclosure

For concrete PromptTemplate examples (summarization, classification, extraction, translation), I/O schema patterns, and caching strategy guidance, see:

- [references/think-node-patterns.md](references/think-node-patterns.md) — Prompt template catalog with 4 complete patterns

## Cross-skill links

- **[floless-smart-nodes](../floless-smart-nodes/SKILL.md)** — Compiled C# nodes; use when logic is deterministic. Always check this skill first before reaching for a Think Node.
- **[floless-workflows](../floless-workflows/SKILL.md)** — Full Flow A/B guide: building workflows from scratch, adding nodes, connecting them, and running the workflow.
- **[floless-cli](../floless-cli/SKILL.md)** — Port file discovery, connection pattern, full command reference, and Stripe-style error envelope details.
