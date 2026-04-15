# Think Node patterns

This reference provides four complete Think Node configurations — each with a full `floless workflow update-think-node` CLI invocation. It also covers I/O schema format, prompt template variable syntax, caching strategy, and token budget management.

---

## I/O schema format

Both `InputSchemaJson` and `OutputSchemaJson` accept **JSON Schema draft-07** strings. The schemas are serialized as single-line JSON strings passed to the CLI options.

### InputSchemaJson

Validated against upstream data **before** the LLM call. If the incoming data does not match the schema, the node errors with `errorCode: "input_schema_violation"` — saving tokens.

```json
{
  "type": "object",
  "properties": {
    "text": { "type": "string", "minLength": 1 }
  },
  "required": ["text"]
}
```

Passed to CLI as a single-line string:
```bash
--input-schema-json '{"type":"object","properties":{"text":{"type":"string","minLength":1}},"required":["text"]}'
```

### OutputSchemaJson

Describes the expected LLM response structure. Only meaningful when `ResponseFormat=json`. The model is instructed to produce JSON matching this schema.

```json
{
  "type": "object",
  "properties": {
    "summary": { "type": "string" },
    "key_points": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["summary", "key_points"]
}
```

CLI form:
```bash
--output-schema-json '{"type":"object","properties":{"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"string"}}},"required":["summary","key_points"]}'
```

> Pass `""` (empty string) to clear either schema field. Schemas are optional — if omitted, the LLM has no structural constraint.

---

## Pattern 1: Summarization

Condense a long text into a structured summary with bullet-point key points.

**Think Node configuration:**

| Property | Value |
|----------|-------|
| `PromptTemplate` | `"Summarize the following document in 2-3 sentences, then list the 3 most important points as an array:\n\n{{action1.result}}"` |
| `SystemPrompt` | `"You are a concise technical writer. Produce factual summaries without adding interpretation."` |
| `Temperature` | `0.3` |
| `ResponseFormat` | `json` |
| `OutputSchemaJson` | `{"type":"object","properties":{"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"string"}}},"required":["summary","key_points"]}` |
| `InputSchemaJson` | `{"type":"object","properties":{"result":{"type":"string","minLength":1}},"required":["result"]}` |
| `IsCachingEnabled` | `true` (summaries of identical documents are deterministic) |

**CLI invocation (replace `{nodeId}` with the target node's GUID):**

```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template "Summarize the following document in 2-3 sentences, then list the 3 most important points as an array:\n\n{{action1.result}}" \
  --system-prompt "You are a concise technical writer. Produce factual summaries without adding interpretation." \
  --model claude-sonnet-4-20250514 \
  --temperature 0.3 \
  --response-format json \
  --output-schema-json '{"type":"object","properties":{"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"string"}}},"required":["summary","key_points"]}' \
  --input-schema-json '{"type":"object","properties":{"result":{"type":"string","minLength":1}},"required":["result"]}' \
  --caching true \
  --json
```

**Expected envelope on success:**
```json
{"success": true, "data": {"nodeId": "{nodeId}", "updated": true}}
```

**Downstream access:** The next node reads `{{summarize.output.summary}}` and `{{summarize.output.key_points}}` (where `summarize` is the Think Node's display name).

---

## Pattern 2: Classification

Assign an input to one of N predefined categories. Use low temperature for deterministic, repeatable classification.

**Think Node configuration:**

| Property | Value |
|----------|-------|
| `PromptTemplate` | `"Classify the following support message into exactly one category: BILLING, TECHNICAL, ACCOUNT, OTHER.\n\nMessage: {{trigger.messageText}}\n\nRespond with only the category name."` |
| `SystemPrompt` | `"You are a support ticket classifier. Output exactly one word from the allowed list. Never explain your reasoning."` |
| `Temperature` | `0.1` |
| `ResponseFormat` | `json` |
| `OutputSchemaJson` | `{"type":"object","properties":{"category":{"type":"string","enum":["BILLING","TECHNICAL","ACCOUNT","OTHER"]}},"required":["category"]}` |
| `IsCachingEnabled` | `true` (same message always maps to same category) |
| `MaxOutputTokens` | `50` (category name is short; prevents runaway output) |

**CLI invocation:**

```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template "Classify the following support message into exactly one category: BILLING, TECHNICAL, ACCOUNT, OTHER.\n\nMessage: {{trigger.messageText}}\n\nRespond with only the category name." \
  --system-prompt "You are a support ticket classifier. Output exactly one word from the allowed list. Never explain your reasoning." \
  --temperature 0.1 \
  --response-format json \
  --output-schema-json '{"type":"object","properties":{"category":{"type":"string","enum":["BILLING","TECHNICAL","ACCOUNT","OTHER"]}},"required":["category"]}' \
  --caching true \
  --max-output-tokens 50 \
  --json
```

**Downstream routing:** A Smart Node after the classifier reads `{{classify.output.category}}` and routes to the correct branch with a deterministic switch — no second LLM call needed.

> **Smart + Think synergy:** Prefer a Think Node only for the initial classification step. All downstream routing based on the category should use Smart Nodes (deterministic, zero cost).

---

## Pattern 3: Extraction

Pull structured fields (name, email, phone, address) from unstructured paragraph text. Use Temperature 0.1 for precision; pair with `InputSchemaJson` to validate the upstream text exists.

**Think Node configuration:**

| Property | Value |
|----------|-------|
| `PromptTemplate` | `"Extract the contact details from the following text. Return all fields you find; use null for missing fields.\n\nText: {{trigger.rawText}}"` |
| `SystemPrompt` | `"You are a data extraction assistant. Extract only what is explicitly stated in the text. Never infer or assume missing information."` |
| `Temperature` | `0.1` |
| `ResponseFormat` | `json` |
| `OutputSchemaJson` | see below |
| `InputSchemaJson` | `{"type":"object","properties":{"rawText":{"type":"string","minLength":10}},"required":["rawText"]}` |
| `IsCachingEnabled` | `true` |

**OutputSchemaJson for extraction:**
```json
{
  "type": "object",
  "properties": {
    "name":    { "type": ["string", "null"] },
    "email":   { "type": ["string", "null"] },
    "phone":   { "type": ["string", "null"] },
    "address": { "type": ["string", "null"] }
  },
  "required": ["name", "email", "phone", "address"]
}
```

**CLI invocation:**

```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template "Extract the contact details from the following text. Return all fields you find; use null for missing fields.\n\nText: {{trigger.rawText}}" \
  --system-prompt "You are a data extraction assistant. Extract only what is explicitly stated in the text. Never infer or assume missing information." \
  --temperature 0.1 \
  --response-format json \
  --output-schema-json '{"type":"object","properties":{"name":{"type":["string","null"]},"email":{"type":["string","null"]},"phone":{"type":["string","null"]},"address":{"type":["string","null"]}},"required":["name","email","phone","address"]}' \
  --input-schema-json '{"type":"object","properties":{"rawText":{"type":"string","minLength":10}},"required":["rawText"]}' \
  --caching true \
  --json
```

**Downstream access:** `{{extract.output.email}}`, `{{extract.output.name}}`, etc. A downstream Smart Node can validate non-null constraints before continuing.

---

## Pattern 4: Translation

Translate input text from a source language to a target language. Use Temperature 0.5 for natural fluency while remaining faithful to the original.

**Think Node configuration:**

| Property | Value |
|----------|-------|
| `PromptTemplate` | `"Translate the following text from {{trigger.sourceLanguage}} to {{trigger.targetLanguage}}. Preserve formatting and tone.\n\nText:\n{{trigger.inputText}}"` |
| `SystemPrompt` | `"You are a professional translator. Preserve the original meaning, tone, and formatting. Do not add commentary or explanations."` |
| `Temperature` | `0.5` |
| `ResponseFormat` | `text` |
| `IsCachingEnabled` | `false` (translation prompts vary by trigger inputs; caching hit rate is low) |
| `MaxOutputTokens` | `2000` |

> Translation does not use `OutputSchemaJson` because `ResponseFormat=text` — the model returns the translated text directly.

**CLI invocation:**

```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template "Translate the following text from {{trigger.sourceLanguage}} to {{trigger.targetLanguage}}. Preserve formatting and tone.\n\nText:\n{{trigger.inputText}}" \
  --system-prompt "You are a professional translator. Preserve the original meaning, tone, and formatting. Do not add commentary or explanations." \
  --temperature 0.5 \
  --response-format text \
  --max-output-tokens 2000 \
  --json
```

**Clearing the output schema** (if previously set to json, now switching to text):

```bash
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --response-format text \
  --output-schema-json "" \
  --json
```

Passing `--output-schema-json ""` clears the field. The `ResponseFormat` update and schema clear are applied atomically in one PATCH call.

**Downstream access:** `{{translate.output}}` contains the translated text string.

---

## Prompt template variable syntax

All variable references inside a `PromptTemplate` value use **double-brace syntax**: `{{path.to.value}}`. This is evaluated by the FloLess workflow engine at execution time.

### Reference patterns

| Pattern | Example | Resolves to |
|---------|---------|-------------|
| Trigger field | `{{trigger.cellValue}}` | Value from the trigger that started the workflow |
| Trigger field (nested) | `{{trigger.payload.subject}}` | Nested field in trigger payload |
| Upstream node result | `{{action1.result}}` | Output of the node named `action1` |
| Named node output field | `{{parseData.output.total}}` | Specific field in a named node's structured output |
| Think Node output field | `{{classify.output.category}}` | Field from a preceding Think Node's JSON output |

### Multi-variable prompt example

```
Summarize the changes in this Tekla model update.

Project: {{trigger.projectName}}
Model file: {{trigger.modelPath}}
Change log: {{action1.result}}

Focus on structural member additions and deletions. Output as JSON.
```

This prompt references two trigger fields and one upstream action result. All three must be available in the data pipeline at execution time — if any are missing, the node errors with `input_resolution_failure` before calling the LLM.

### Stdin and file-based templates

For long prompts, use stdin (`-`) or a file reference (`@path/to/file`) instead of inline strings:

```bash
# Read PromptTemplate from a file
floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template @prompts/summarization-prompt.txt \
  --json

# Read PromptTemplate from stdin
echo "Summarize: {{action1.result}}" | floless workflow update-think-node \
  --workflow current \
  --node {nodeId} \
  --prompt-template - \
  --json
```

---

## Caching strategy

`IsCachingEnabled` caches LLM responses keyed on the exact rendered prompt + input values. A cache hit skips the LLM call entirely — zero latency, zero cost.

### When to enable caching

Enable `IsCachingEnabled=true` when:

- The PromptTemplate is static (no time-sensitive variables like "today's date" or "current price")
- Inputs repeat frequently (same document summarized multiple times, same message classified repeatedly)
- Output is deterministic for a given input (classification, extraction, translation of identical text)
- Temperature is low (0.1–0.3) — high temperature with caching produces staleness on varied inputs

### When to disable caching

Disable `IsCachingEnabled=false` (or omit — defaults to false) when:

- Prompts include dynamic values that change on every run (timestamps, counters, live data)
- You explicitly want fresh LLM responses even for repeated inputs
- Temperature is high (0.7+) and output variety is desirable

### Cache invalidation

The cache is keyed on the exact rendered prompt string after variable substitution. Changing any variable value — or changing the `PromptTemplate` itself — produces a cache miss on the next execution. There is no manual cache-clear command; modify any prompt variable to force a miss.

---

## Token budgets

### MaxInputTokens

Set to prevent the Think Node from sending oversized prompts to the LLM. The check runs **before** the LLM call — if the rendered prompt token count exceeds this value, the node errors with `errorCode: "input_token_budget_exceeded"` and no LLM call is made.

```bash
--max-input-tokens 4000
```

Use this as a safety guard when upstream actions can produce variable-length output (e.g., raw web scrapes, model change logs).

### MaxOutputTokens

Passed directly as `max_tokens` to the LLM API. Hard-ceiling on response length. The LLM stops generating at this token count.

```bash
--max-output-tokens 500
```

Recommended settings by pattern:

| Pattern | MaxInputTokens | MaxOutputTokens |
|---------|---------------|-----------------|
| Classification | 2000 | 50 |
| Extraction (short text) | 2000 | 500 |
| Summarization | 8000 | 1000 |
| Translation | 4000 | 2000 |

> Both fields are non-nullable integers. Pass a valid integer to update; omit the option to leave unchanged. Empty string is rejected with `errorCode: "invalid_empty_string"`.
