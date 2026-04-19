---
name: floless-overview
description: Learn what FloLess is, its node taxonomy, and how to build your first workflow from an AI terminal. Use when first encountering FloLess from Claude Code, Codex CLI, or OpenCode — or when deciding which specialty floless-* skill to load next. Covers node types (Trigger, Action, Smart Node, Think Node, Condition, Display), provider landscape (Excel, File, Tekla, Trimble Connect, HTTP, Email, Teams), Flow A vs Flow B architecture, and an end-to-end first-workflow walkthrough.
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read
---

# floless-overview

## What is FloLess

FloLess is a visual workflow automation application for structural engineers and AEC professionals. It enables users to create workflows with triggers, actions, and nodes that automate repetitive tasks in Tekla Structures and integrate with cloud services — Trimble Connect, Excel, HTTP APIs, email (IMAP), and Microsoft Teams. Workflows are built visually in the desktop app and driven programmatically via the `floless` CLI. The CLI is the AI-terminal interface: every command emits structured JSON that AI agents can parse, react to, and loop on without any human interaction.

FloLess is a product by BIMstudio. It is not a scripting language — users design workflows visually. AI agents extend this by constructing or modifying workflows via the CLI, then handing execution back to the desktop.

---

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

---

## When to use this skill

Load `floless-overview` when:

- You are encountering FloLess for the first time from an AI terminal and need a conceptual foundation before issuing any CLI commands.
- You need to decide which specialty `floless-*` skill to load next (use the cross-link section at the end of this file).
- You need to understand the 6 primary node types and what each one does.
- You need to understand Flow A (build from scratch) vs Flow B (augment a live workflow).
- You want a guided walkthrough of creating your very first workflow end-to-end.
- You need the provider landscape — which external systems FloLess can connect to.

Do NOT load this skill when you already know which specialty domain you are working in. Instead load the appropriate specialty skill directly to avoid loading this overview body unnecessarily:

- Port file mechanics, connection pattern, envelope shape → `floless-cli`
- Building or modifying workflows in JSON → `floless-workflows`
- Compiled C# Smart Nodes → `floless-smart-nodes`
- LLM Think Nodes → `floless-think-nodes`
- Trigger catalog (all 45+ types) → `floless-triggers`
- Canvas layout and X/Y positioning → `floless-canvas`

---

## Node taxonomy

FloLess workflows are composed of **6 primary node types** plus **8 secondary types**.

### Primary node types

**Trigger**
Starts a workflow. Triggers watch for external events and fire the downstream action chain when the event occurs. Examples: Excel cell change, Tekla model event, file write, HTTP webhook, schedule, incoming email, Teams message. Every workflow must have exactly one Trigger.

**Action**
Performs a single step — reads a file, calls an API, updates the Tekla model, sends an email. Actions are discoverable via `floless actions --json [--provider {provider}]`. Chaining multiple Actions creates multi-step pipelines.

**Smart Node**
A compiled C# code node. Zero runtime token cost. Deterministic — same input always produces the same output. Use for string transforms, numeric calculations, data reshaping, or any logic that does not require AI reasoning. Smart Nodes are compiled by the desktop; you iterate via the `floless compile` command. See the `floless-smart-nodes` skill.

**Think Node**
An LLM call per workflow execution. Each execution consumes tokens from the configured model (Claude, GPT-4, Gemini, etc.). Use for AI reasoning, classification, summarization, extraction, and translation — logic that is non-deterministic or language-dependent. See the `floless-think-nodes` skill.

**Condition**
A branching node with true/false output ports. Evaluates a boolean expression on its input and routes execution to the matching port. Conditions chain with Actions to create conditional pipelines.

**Display**
Presents output in the FloLess desktop terminal. Use as the final node in a chain to surface results to the user. Always use the short name `Display` in CLI commands and JSON (the long-form alias is deprecated — use `Display` exclusively).

### Secondary node types (brief)

Iterator, Aggregator, DataProcessing, Input, Cluster, Note, Group, and Connector. These enable looping, data accumulation, grouping, and workflow organization. They are covered in `floless-workflows` and `floless-canvas`.

---

## Provider landscape

FloLess ships built-in providers covering the most common AEC and office data sources. Discover available triggers and actions per provider via `floless triggers --json --provider {provider}` and `floless actions --json --provider {provider}`.

- **Excel** — cell change triggers, read/write cell ranges, table operations
- **File** — file watch triggers, read/write/move/delete file actions
- **HTTP** — webhook triggers, GET/POST/PUT/DELETE action calls to external REST APIs
- **Tekla** — Tekla Structures model events (open, save, select, model change), model read/write actions
- **Trimble Connect** — cloud file sync, project document actions
- **Email** — IMAP email arrival trigger, send email action
- **Teams** — Microsoft Teams message trigger and send-message action

---

## Flow A vs Flow B

FloLess supports two workflow construction patterns. Choose based on whether a workflow already exists in the desktop.

### Flow A — Build from scratch

Use Flow A when no workflow is open in the desktop, or when you want to produce a new `.flo` file for the user to open.

**How it works:**

1. Fetch the workflow JSON schema: `floless schema --type workflow --json`
2. Construct a workflow JSON document that conforms to the schema (one Trigger → one or more Actions → one Display is the minimal valid structure).
3. Create the `.flo` file from the JSON:
   ```
   floless workflow create --input workflow.json --output first.flo --json
   ```
4. The user opens `first.flo` in the desktop (or use `floless workflow open --path first.flo --json`).
5. The workflow appears on the canvas, ready to run.

**Variable references in Flow A:** Use `{{trigger.fieldName}}` and `{{action1.result}}` (double braces) in Action and Display configs to wire data between nodes. The runtime evaluates these at execution time.

**Example workflow shape (Excel trigger → Text Panel display):**

```json
{
  "Version": "1.0.0",
  "Name": "My First Workflow",
  "Nodes": [
    {
      "Id": "trigger-1",
      "NodeType": "Trigger",
      "X": 0, "Y": 0,
      "ComponentId": "excel-cell-changed",
      "Config": { "filePath": "C:\\data.xlsx", "sheetName": "Sheet1", "cellAddress": "A1" }
    },
    {
      "Id": "display-1",
      "NodeType": "Display",
      "X": 0, "Y": 200,
      "ComponentId": "multiline-text",
      "Config": { "text": "Cell changed: {{trigger.cellValue}}" }
    }
  ],
  "Connections": [
    { "SourceNodeId": "trigger-1", "SourcePortIndex": 0, "TargetNodeId": "display-1", "TargetPortIndex": 0 }
  ]
}
```

All fields are PascalCase (`Nodes`, `Connections`, `NodeType`, `ComponentId`, `Config`, `Version`). `ComponentId` is the kebab-case slug of a real component — verify with `floless nodes --json`, `floless triggers --json`, or `floless component <id> --json`. Never invent names like `ExcelCellChangeTrigger`.

### Flow B — Augment the live workflow

Use Flow B when a workflow is already open in the FloLess desktop and you want to add, remove, or modify nodes without replacing the whole file. Changes appear on the canvas immediately.

**How it works:** Use the `--workflow current` keyword with mutation subcommands. The desktop's currently-loaded workflow is the target — no file path needed.

**Key mutation commands:**

```
floless workflow add-node    --workflow current --type {NodeType} --json
floless workflow connect      --workflow current --from {nodeId} --from-port 0 --to {nodeId2} --to-port 0 --json
floless workflow delete-node  --workflow current --node {nodeId} --json
floless workflow update-think-node --workflow current --node {nodeId} --prompt-template "..." --json
floless workflow export       --workflow current --output updated.flo --json
```

**When to use Flow B:** The user already has a workflow open and wants iterative changes — add a Think Node, rewire a connection, update an Action's config — without closing and reopening. More interactive than Flow A.

See the `floless-workflows` skill for the complete Flow B reference including `add-node` option syntax per node type, `node-context`, and `disconnect`.

---

## First-workflow walkthrough

This walkthrough creates a minimal Excel-to-Display workflow using Flow A.

**Prerequisites:** FloLess desktop app installed on Windows, `floless` CLI on PATH.

1. **Launch the desktop** (if not already running):
   ```
   floless start --json
   ```

2. **Confirm the connection works:**
   ```
   floless nodes --json
   ```
   Expected: `{success: true, data: [...], count: N}`. If this fails, the desktop is not running or the port file is missing — run `floless start` again.

3. **Browse available triggers for Excel:**
   ```
   floless triggers --json --provider excel
   ```
   Note the `componentId` field of the trigger you want to use (e.g., `excel-cell-changed`). This kebab-case slug is what you put in the workflow JSON's `ComponentId` field.

4. **Browse available actions for Tekla** (or another provider):
   ```
   floless actions --json --provider tekla
   ```
   Note the `componentId` field of the action you want to chain.

5. **Fetch the workflow JSON schema:**
   ```
   floless schema --type workflow --json
   ```
   Use the returned schema to understand required and optional fields for each node type.

6. **Construct a minimal workflow JSON:**

   Create `workflow.json` with one Trigger → one Display (the simplest valid workflow). Schema is PascalCase; `ComponentId` must reference a real component from `floless triggers --json` / `floless component <id> --json`:

   ```json
   {
     "Version": "1.0.0",
     "Name": "First Workflow",
     "Nodes": [
       {
         "Id": "trigger-1",
         "NodeType": "Trigger",
         "X": 0, "Y": 0,
         "ComponentId": "excel-cell-changed",
         "Config": { "filePath": "C:\\Users\\you\\data.xlsx", "sheetName": "Sheet1", "cellAddress": "B2" }
       },
       {
         "Id": "display-1",
         "NodeType": "Display",
         "X": 0, "Y": 200,
         "ComponentId": "multiline-text",
         "Config": { "text": "Excel changed: {{trigger.cellValue}}" }
       }
     ],
     "Connections": [
       { "SourceNodeId": "trigger-1", "SourcePortIndex": 0, "TargetNodeId": "display-1", "TargetPortIndex": 0 }
     ]
   }
   ```

7. **Create the `.flo` file:**
   ```
   floless workflow create --input workflow.json --output first.flo --json
   ```
   Expected: `{success: true, data: {path: "first.flo"}}`.

8. **Open in the desktop:**
   ```
   floless workflow open --path first.flo --json
   ```
   Or have the user open `first.flo` manually from the desktop File menu.

9. **Run the workflow:**
   - **Interactive:** Click the Play button in the FloLess desktop.
   - **Headless:** `floless workflow run --wait --json` (waits for completion and returns output).
   - **Stop a running workflow:** `floless workflow stop --json`.

---

## Explicit non-capabilities

Understanding what FloLess CLI cannot do helps avoid wasted iteration.

- **Runtime error debugging:** When a workflow execution fails, the desktop UI surfaces the error with node-level detail. The CLI can report that a run completed or failed (`workflow run --wait` returns `data.status`), but it does not expose per-node execution logs via CLI. Use the desktop UI for debugging.
- **Live provider state inspection:** You cannot read an Excel cell value or query the Tekla model state via CLI without adding a Trigger and running the workflow. The CLI is a workflow management interface, not a data query interface.
- **Headless execution without the desktop:** `floless workflow run` and `floless workflow stop` require the FloLess desktop app to be running — they send commands to the desktop's CLI API. True server-side headless execution without a desktop process is not supported in v1.

Note: the `floless workflow run [--wait]` and `floless workflow stop` commands, added in the 69.x CLI release, DO enable headless-style execution control for automation pipelines — the desktop runs in the background while the CLI drives and polls the run. This is the recommended pattern for CI/CD or scheduled automations.

---

## Available skills in this plugin

<!-- SKILLS_LINKS_START -->
<!-- DO NOT EDIT — regenerated by scripts/generate-readme-toc.sh -->
- [floless-canvas](../floless-canvas/SKILL.md) — see the floless-canvas skill
- [floless-cli](../floless-cli/SKILL.md) — see the floless-cli skill
- [floless-overview](../floless-overview/SKILL.md) — see the floless-overview skill
- [floless-smart-nodes](../floless-smart-nodes/SKILL.md) — see the floless-smart-nodes skill
- [floless-think-nodes](../floless-think-nodes/SKILL.md) — see the floless-think-nodes skill
- [floless-triggers](../floless-triggers/SKILL.md) — see the floless-triggers skill
- [floless-workflows](../floless-workflows/SKILL.md) — see the floless-workflows skill
<!-- SKILLS_LINKS_END -->

---

## Scope boundaries

This overview skill deliberately omits deep technical content that belongs in specialty skills. Use the links below to go deeper.

| Topic | Go to skill |
|-------|-------------|
| Port file location, format, and connection pattern | `floless-cli` |
| Full CLI command reference (all 24 commands with options and exit codes) | `floless-cli` |
| Stripe-style envelope shape (`errorCode`, `errorWrapper.details`) | `floless-cli` |
| Desktop lifecycle (`floless start`, `floless close`) | `floless-cli` |
| `.flo` JSON schema in full | `floless-workflows` |
| Flow B mutation commands in depth (`add-node`, `connect`, `disconnect`, `node-context`) | `floless-workflows` |
| Variable templating (`{{trigger.cellValue}}`, `{{action1.result}}`) | `floless-workflows` |
| Workflow execution control (`workflow run`, `workflow stop`) | `floless-workflows` |
| C# Smart Node entry point, ports, compile-fix loop | `floless-smart-nodes` |
| Think Node prompt templates, model selection, I/O schemas | `floless-think-nodes` |
| All 45+ trigger types with per-type config schemas | `floless-triggers` |
| Canvas X/Y positioning, port index semantics, layout best practices | `floless-canvas` |
