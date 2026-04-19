---
name: floless-workflows
description: "Build and modify FloLess workflows (.flo files) from any AI terminal. Use when creating a workflow from scratch (Flow A), augmenting a workflow loaded in the desktop (Flow B), running or stopping a workflow headlessly, validating workflow JSON, or passing variables between nodes with {{trigger.cellValue}}/{{action1.result}} templating. Covers all 17 workflow subcommands — create, validate, info, list, nodes, node-context, add-node, delete-node, connect, disconnect, update-think-node, export, open, save, save-as, run, stop."
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read Write
---

# floless-workflows

FloLess workflows are JSON files with a `.flo` extension. They describe a directed graph of nodes
(Trigger, Action, SmartNode, ThinkNode, Condition, Display, etc.) connected by typed edges.
Every workflow must have exactly one Trigger node, at least one other node, and a Version field.

This skill covers **two fundamental authoring flows** plus lifecycle and execution control:

- **Flow A** — build a workflow from scratch, producing a `.flo` file on disk
- **Flow B** — augment a workflow already loaded in the FloLess desktop (the `'current'` workflow)

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

## When to use this skill

| Scenario | Use |
|---|---|
| Build a new workflow from a blank canvas | Flow A (`workflow create`) |
| Inspect/modify the workflow open in the desktop | Flow B (`workflow nodes`, `workflow add-node`, etc.) |
| Save or open a workflow file headlessly | Lifecycle (`workflow open`, `workflow save`, `workflow save-as`) |
| Start or stop execution from a script | Execution control (`workflow run`, `workflow stop`) |
| Check a JSON file is structurally valid | `workflow validate` |

## The .flo format at a glance

```json
{
  "Name": "My Workflow",
  "Version": "1.0",
  "Nodes": [ ... ],
  "Connections": [ ... ],
  "Settings": { ... }
}
```

Full field-by-field reference: see [references/workflow-schema.md](references/workflow-schema.md).

## Flow A — build from scratch

Flow A produces a `.flo` file that you can open in the desktop or share with teammates.
It does **not** modify a running desktop session.

**5-step sequence:**

### A1 — Discover available node types and components

```bash
# List all node types (SmartNode, ThinkNode, Trigger, Action, Condition, Display, ...)
floless nodes --json

# Discover trigger component IDs for a provider (e.g., excel)
floless triggers --json --provider excel

# Discover action component IDs for a provider (e.g., tekla)
floless actions --json --provider tekla
```

### A2 — Fetch the workflow JSON schema

```bash
# Returns the authoritative JSON schema for the .flo format
floless schema --type workflow --json
```

### A3 — Construct the workflow JSON

Hand-construct the JSON according to the schema. Key rules:

- `Version` is required (use `"1.0"`)
- `Nodes` must have at least 1 node; exactly 1 must be a Trigger
- All node `Id` values must be non-empty and unique (GUIDs recommended)
- All `NodeType` values must be valid (server enforces via `NodeTypeRegistry`)
- Connections reference existing node IDs; no cycles allowed

Minimal valid example — see [references/examples.md](references/examples.md#example-1-minimal--trigger--display).

### A4 — Validate before saving

```bash
# Validate a draft JSON file (positional argument = file path)
floless workflow validate draft.json --json
```

### A5 — Save as a .flo file

```bash
# Create a .flo file from a JSON input file
floless workflow create --input draft.json --output my-workflow.flo --json

# Or pipe JSON directly from stdin
cat draft.json | floless workflow create --output my-workflow.flo --json

# Override name and/or description during create
floless workflow create --input draft.json --output my-workflow.flo \
  --name "Excel to Tekla Sync" --description "Syncs changes from Excel to Tekla" --json
```

Inspect the result:

```bash
floless workflow info my-workflow.flo --json
```

## Flow B — augment a loaded workflow

Flow B mutates the workflow currently open in the FloLess desktop. The special identifier
`'current'` (passed as `--workflow current`) refers to the active workflow in the desktop UI.
You do not need a file path; the desktop handles persistence.

**Use `'current'` any time a command accepts `--workflow`.**

**8-step augmentation sequence:**

### B1 — Confirm a workflow is loaded

```bash
floless workflow list --json
# Returns the list of open workflows; confirms 'current' is available
```

### B2 — Inspect existing nodes

```bash
# List all nodes in the current workflow
floless workflow nodes --workflow current --json
```

### B3 — Drill into a specific node

```bash
# Replace {nodeGuid} with the target node's GUID (preferred) or name (fallback)
floless workflow node-context --workflow current --node {nodeGuid} --json

# Name fallback (use only when GUID is unavailable)
floless workflow node-context --workflow current --node "My Smart Node" --json
```

### B4 — Add a new node

```bash
# Add a SmartNode at explicit canvas coordinates
floless workflow add-node --workflow current \
  --type SmartNode --title "Process Data" --x 400 --y 200 --json

# Add a Trigger node (requires --component-id)
floless workflow add-node --workflow current \
  --type Trigger --title "File Watcher" \
  --component-id folder-watcher --x 100 --y 200 --json

# Add an Action node (requires --component-id)
floless workflow add-node --workflow current \
  --type Action --title "Send Email" \
  --component-id email-send --x 700 --y 200 --json
```

`--x` and `--y` are optional; omit them to place the node at the viewport center.
Use `floless actions --json` or `floless triggers --json` to discover component IDs.

### B5 — Wire nodes together

```bash
# Connect two nodes: --from {sourceGuid} --from-port N --to {targetGuid} --to-port N
floless workflow connect --workflow current \
  --from abc-123-trigger --from-port 0 \
  --to def-456-action --to-port 0 --json
```

Ports are **0-based**. See [references/workflow-schema.md](references/workflow-schema.md#port-index-semantics)
and the `floless-canvas` skill for the port index table per node type.
The CLI enforces cycle detection and type compatibility — a `cycle_detected` or
`port_incompatible` error means the wire is not allowed.

### B6 — Remove a node

```bash
# Remove node by GUID (cascade-deletes all its connections; supports undo in the desktop)
floless workflow delete-node --workflow current --node {nodeGuid} --json
```

### B7 — Update a ThinkNode

```bash
# PATCH semantics: only provided fields change; omit a field to leave it unchanged
floless workflow update-think-node --workflow current --node {nodeGuid} \
  --prompt-template "Summarize: {{trigger.body}}" \
  --model claude-sonnet-4-20250514 --temperature 0.3 --json
```

Deep dive on ThinkNode configuration (model, temperature, schemas, response-format):
see the `floless-think-nodes` skill.

### B8 — Export a canonical snapshot

```bash
# Export the current workflow JSON to stdout
floless workflow export --workflow current --json

# Export to file (read-only snapshot — does NOT update the desktop's CurrentFilePath)
floless workflow export --workflow current --output snapshot.json
```

`workflow export` is a **read-only snapshot**. It does not save or alter the desktop's
current file path. To persist changes to disk, use `workflow save` or `workflow save-as`.

## GUID-first lookup with name fallback (69.1.2 D-01)

All `--node` and `--workflow` options accept either a GUID (preferred) or a display name
(fallback). Always prefer GUIDs — names are not unique and may change.

```bash
# PREFERRED: GUID
floless workflow node-context --workflow current --node abc-123-def-456 --json

# FALLBACK: name (only when GUID is unavailable)
floless workflow node-context --workflow current --node "My Smart Node" --json
```

Obtain node GUIDs via `floless workflow nodes --workflow current --json`.

## Variable templating — `{variable}` vs `{{variable}}` (69.1.2 D-05)

**Critical distinction:**

| Context | Syntax | Example |
|---|---|---|
| Prose / skill documentation (placeholder) | `{variable}` | "Replace `{nodeGuid}` with the target node's GUID" |
| Literal runtime .flo JSON (engine evaluates) | `{{variable}}` | `"PromptTemplate": "Summarize: {{trigger.body}}"` |

When you write skill documentation or describe placeholders, use single braces: `{nodeGuid}`,
`{workflowId}`. When you write actual .flo JSON field values that the FloLess engine will
evaluate at runtime, use double braces: `{{trigger.cellValue}}`, `{{action1.result}}`.

**Available runtime variables:**

- `{{trigger.cellValue}}` — value from an Excel trigger's changed cell
- `{{trigger.body}}` — payload body from an HTTP webhook trigger
- `{{trigger.filePath}}` — path from a folder-watcher trigger
- `{{action1.result}}` — output of the first action node (named by node title)
- `{{action2.result}}` — output of the second action node
- `{{nodeTitle.fieldName}}` — any output field from any upstream node

Variable references must match the output schema of the upstream node. Use
`floless workflow node-context --workflow current --node {nodeGuid} --json` to inspect
what output fields a node exposes.

## Validation rules

Run `floless workflow validate file.json --json` to get a structured report.

| Rule | Detail |
|---|---|
| `Version` required | Must be present (use `"1.0"`) |
| At least 1 node | `Nodes` array cannot be empty |
| Exactly 1 Trigger | Workflow cannot have 0 or 2+ Trigger nodes |
| No empty node IDs | Every node `Id` must be a non-empty string |
| No duplicate node IDs | All `Id` values must be unique within `Nodes` |
| Valid `NodeType` | Must match values in `NodeTypeRegistry` (see schema reference) |
| Connections reference existing nodes | `SourceNodeId` and `TargetNodeId` must exist in `Nodes` |
| Connection ports must exist | Port indices must be valid for the source/target `NodeType` |
| No cycles | The connection graph must be a DAG |

## Lifecycle commands (69.x additions — workflow open / save / save-as)

These three commands bridge file system and the running desktop. They were added in the
`69.x` commit series and are **not** listed in older CONTEXT.md D-16 references.

### workflow open

```bash
# Open a .flo file in the running desktop (headless File > Open)
floless workflow open --file my-workflow.flo --json

# Discard unsaved desktop edits before opening
floless workflow open --file my-workflow.flo --force --json
```

Without `--force`, fails with `conflict_dirty_workflow` if the desktop has unsaved edits.
On success, the desktop loads the file and replaces whatever was open.

### workflow save

```bash
# Save to the existing file path (headless Ctrl+S)
floless workflow save --json
```

Fails with `conflict_no_current_path` if the workflow is Untitled (has never been saved).
In that case, use `workflow save-as`:

```bash
floless workflow save-as --output my-workflow.flo --json
```

### workflow save-as

```bash
# Save to a new path (headless File > Save As)
# Updates the desktop's CurrentFilePath and clears the dirty flag
floless workflow save-as --output path/to/new.flo --json
```

**Key distinction from `workflow export`:**
- `workflow export` is **read-only** — it snapshots the JSON without changing desktop state.
- `workflow save` / `workflow save-as` **mutate desktop state** — they update `CurrentFilePath`
  and clear the dirty flag, exactly like the File > Save menu item.

## Execution control

```bash
# Start execution (fire-and-forget)
floless workflow run --json

# Start execution and block until it completes; returns final status
floless workflow run --wait --json

# Stop a running workflow
floless workflow stop --json
```

`workflow run` triggers the same execution path as clicking the Play button in the desktop.
`workflow run --wait` is useful in scripts that need to sequence actions after the workflow
finishes. `workflow stop` is idempotent — calling it when no workflow is running returns success.

## Worked example: build a 3-node Flow A workflow

Goal: create a workflow that watches for Excel cell changes and logs the value.

```json
{
  "Name": "Excel Cell Logger",
  "Version": "1.0",
  "Nodes": [
    {
      "Id": "trigger-1",
      "NodeType": "Trigger",
      "Title": "Excel Cell Changed",
      "ComponentId": "excel-cell-changed",
      "X": 100,
      "Y": 200
    },
    {
      "Id": "action-1",
      "NodeType": "Action",
      "Title": "Log Value",
      "ComponentId": "log",
      "X": 400,
      "Y": 200,
      "Arguments": {
        "Message": "Cell changed: {{trigger.cellValue}}"
      }
    },
    {
      "Id": "display-1",
      "NodeType": "Display",
      "Title": "Result",
      "X": 700,
      "Y": 200
    }
  ],
  "Connections": [
    { "SourceNodeId": "trigger-1", "SourcePortIndex": 0, "TargetNodeId": "action-1", "TargetPortIndex": 0 },
    { "SourceNodeId": "action-1", "SourcePortIndex": 0, "TargetNodeId": "display-1", "TargetPortIndex": 0 }
  ],
  "Settings": {}
}
```

Save to file and validate:

```bash
floless workflow validate draft.json --json
floless workflow create --input draft.json --output excel-logger.flo --json
floless workflow info excel-logger.flo --json
```

## Worked example: Flow B augmentation — insert a SmartNode

Starting from a loaded workflow with a Trigger (`abc-trigger`) connected directly to a
Display (`xyz-display`), insert a SmartNode between them.

```bash
# 1. Confirm workflow is loaded
floless workflow list --json

# 2. Inspect nodes — note the GUIDs
floless workflow nodes --workflow current --json

# 3. Add a SmartNode between Trigger and Display
floless workflow add-node --workflow current \
  --type SmartNode --title "Process Data" --x 400 --y 200 --json
# Response includes the new node's GUID — call it "smart-guid" below

# 4. Disconnect the existing direct connection
floless workflow disconnect --workflow current \
  --from abc-trigger --to xyz-display --json

# 5. Wire Trigger → SmartNode
floless workflow connect --workflow current \
  --from abc-trigger --from-port 0 --to smart-guid --to-port 0 --json

# 6. Wire SmartNode → Display
floless workflow connect --workflow current \
  --from smart-guid --from-port 0 --to xyz-display --to-port 0 --json

# 7. Export a snapshot to verify the topology
floless workflow export --workflow current --json
```

## Common errors

| Error code | Meaning | Fix |
|---|---|---|
| `not_found_workflow` | No workflow matches `--workflow` value | Check `floless workflow list --json`; ensure desktop has a workflow open |
| `not_found_node` | Node ID not found in the workflow | Use `floless workflow nodes --workflow current --json` to get valid IDs |
| `invalid_workflow` | JSON failed validation | Run `floless workflow validate file.json --json` for details |
| `cycle_detected` | Connection would create a loop | Redesign the topology to eliminate the back-edge |
| `port_incompatible` | Source/target port types mismatch | Check port index semantics in `floless-canvas` skill |
| `conflict_no_current_path` | `workflow save` called on an Untitled workflow | Use `floless workflow save-as --output path.flo --json` |
| `conflict_dirty_workflow` | `workflow open` called but desktop has unsaved edits | Add `--force` to discard edits, or `workflow save` first |

## Progressive disclosure

- Full `.flo` JSON schema (Nodes, Connections, Settings, NodeType catalog, port indices):
  [references/workflow-schema.md](references/workflow-schema.md)
- Complete workflow JSON examples (minimal, Excel-to-Tekla, multi-action variable passing,
  Flow B trace): [references/examples.md](references/examples.md)

## Cross-skill links

| Skill | Covers |
|---|---|
| `floless-cli` | Port file discovery, connection pattern, response envelope, all CLI commands reference |
| `floless-smart-nodes` | C# code authoring for SmartNode nodes used in Flow B |
| `floless-think-nodes` | ThinkNode LLM config, `update-think-node` deep dive |
| `floless-triggers` | Full trigger catalog with per-trigger configuration patterns |
| `floless-canvas` | Canvas X/Y positioning, port index semantics by node type |
| `floless-overview` | What FloLess is, node taxonomy, first-workflow walkthrough |
