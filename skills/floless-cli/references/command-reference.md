# floless CLI command reference

Exhaustive reference for all 27 shipping commands as of FloLess CLI v1.0.0.
All examples use `--json`. All commands return envelope `{success, data, count?, error?, errorCode?, errorWrapper?}`.
Exit codes: 0 = success, 1 = failure.

> **Compile gotcha:** `success: true` means the API call succeeded, NOT that compilation succeeded.
> Always check `data.compiled`. See [The compile gotcha](#the-compile-gotcha) at the bottom.

---

## Table of contents

Top-level: [nodes](#floless-nodes) · [triggers](#floless-triggers) · [actions](#floless-actions) · [component](#floless-component) · [skills](#floless-skills) · [templates](#floless-templates) · [schema](#floless-schema) · [compile](#floless-compile) · [start](#floless-start) · [close](#floless-close)

Workflow: [create](#floless-workflow-create) · [validate](#floless-workflow-validate) · [info](#floless-workflow-info) · [list](#floless-workflow-list) · [nodes](#floless-workflow-nodes) · [node-context](#floless-workflow-node-context) · [add-node](#floless-workflow-add-node) · [delete-node](#floless-workflow-delete-node) · [connect](#floless-workflow-connect) · [disconnect](#floless-workflow-disconnect) · [update-think-node](#floless-workflow-update-think-node) · [export](#floless-workflow-export) · [open](#floless-workflow-open) · [save](#floless-workflow-save) · [save-as](#floless-workflow-save-as) · [run](#floless-workflow-run) · [stop](#floless-workflow-stop)

---

## Top-level commands

### `floless nodes`

**Source:** `NodesCommand.cs:15` | **Purpose:** List all node types from the component catalog.

Options: `--json`, `--category <string>` (e.g., `Triggers`, `Actions`, `Input`)

```bash
floless nodes --json
floless nodes --category Triggers --json
```

Output: `{ "success": true, "data": [{ "componentId": "smart-node", "name": "Smart Node", "nodeType": "SmartNode", "category": "Core" }], "count": 42 }`

---

### `floless triggers`

**Source:** `TriggersCommand.cs:15` | **Purpose:** List available trigger components.

Options: `--json`, `--provider <string>` (case-insensitive substring match, e.g., `Tekla`, `Excel`)

```bash
floless triggers --json
floless triggers --provider Tekla --json
```

Output: `{ "success": true, "data": [{ "componentId": "excel-cell-changed", "name": "Excel Cell Changed", "providerName": "Excel", "parameters": [...] }], "count": 12 }`

---

### `floless actions`

**Source:** `ActionsCommand.cs:15` | **Purpose:** List available action components.

Options: `--json`, `--provider <string>` (case-insensitive substring match)

```bash
floless actions --json
floless actions --provider Tekla --json
```

Output: `{ "success": true, "data": [{ "componentId": "tekla-get-beams", "name": "Get Beams", "providerName": "Tekla Model" }], "count": 45 }`

---

### `floless component`

**Source:** `ComponentCommand.cs:18` | **Purpose:** Show full detail for a specific component including parameters and outputs.

Arguments: `componentId` (required, e.g., `excel-cell-changed`)
Options: `--json`

```bash
floless component excel-cell-changed --json
```

Output: `{ "success": true, "data": { "componentId": "excel-cell-changed", "name": "Excel Cell Changed", "nodeType": "Trigger", "providerName": "Excel", "parameters": [...], "outputs": [...] } }`

Error when not found: `errorCode: not_found_component`

---

### `floless skills`

**Source:** `SkillsCommand.cs:15` | **Purpose:** List available Smart Node skills by name and description.

Options: `--json`, `--group <string>` (e.g., `Core`, `Tekla`, `M365`, `Google`, `TrimbleConnect`, `General`)

```bash
floless skills --json
floless skills --group Tekla --json
```

Output: `{ "success": true, "data": [{ "name": "GetBeams", "group": "Tekla", "source": "Built-in", "description": "..." }], "count": 30 }`

---

### `floless templates`

**Source:** `TemplatesCommand.cs:15` | **Purpose:** List available Smart Node and Think Node templates.

Options: `--json`, `--type <string>` (filter: `smart`, `think`, or `prompt`)

```bash
floless templates --json
floless templates --type smart --json
floless templates --type think --json
```

Output: `{ "success": true, "data": [{ "id": "smart-hello-world", "title": "Hello World", "category": "Core", "source": "Built-in" }], "count": 15 }`

---

### `floless schema`

**Source:** `SchemaCommand.cs:12` | **Purpose:** Output JSON Schema for the `.flo` file format. Always outputs JSON — no `--json` flag needed or available.

Options: `--type <string>` (default: `workflow`; also: `node`, `connection`, `smartnode`, `thinknode`)

```bash
floless schema
floless schema --type workflow
floless schema --type smartnode
floless schema --type thinknode
```

Output is raw JSON Schema (not a Stripe envelope). Exit 0 on success, 1 on failure.

---

### `floless compile`

**Source:** `CompileCommand.cs:25` | **Purpose:** Compile C# code via the desktop's Roslyn pipeline. Optionally updates a node in the loaded workflow.

> **CRITICAL:** `success: true` ≠ compilation succeeded. Check `data.compiled`. See bottom of this file.

Options:

| Option | Required | Description |
|--------|----------|-------------|
| `--code <file>` | No | C# source file. Reads stdin if omitted — **never omit without piping stdin (hangs on TTY)** |
| `--workflow <id>` | No | `current` for active workflow or a file path |
| `--node <id>` | No | Node ID to compile for (requires `--workflow`) |
| `--instructions <text>` | No | Override the Smart Node instructions text |
| `--target-framework <fw>` | No | `net8.0` (default) or `net48` |
| `--software-version <ver>` | No | Target software version (e.g., `tekla-2025`) |
| `--json` | No | Output raw JSON response |

**Request body limit: 1 MB** (`errorCode: payload_too_large` if exceeded).

```bash
floless compile --code MyNode.cs --json
floless compile --code MyNode.cs --workflow current --node abc-123 --json
floless compile --code MyNode.cs --target-framework net48 --software-version tekla-2025 --json
cat MyNode.cs | floless compile --json
```

**Output — compilation success:**

```json
{ "success": true, "data": { "compiled": true, "nodeUpdated": true, "diagnostics": [] } }
```

**Output — compilation failure (note: `success: true` but `data.compiled: false`):**

```json
{
  "success": true,
  "data": {
    "compiled": false,
    "nodeUpdated": false,
    "diagnostics": [{ "severity": "Error", "id": "CS0246", "message": "Type 'Foo' not found", "line": 12, "column": 9 }]
  }
}
```

Exit code 0 only when `success: true` AND `data.compiled: true`. Exit 1 otherwise.

---

### `floless start`

**Source:** `AppCommand.cs:CreateStartCommand():48` | **Purpose:** Launch FloLess desktop and wait until its HTTP API is responsive. Idempotent — returns success if already running.

Options:

| Option | Default | Description |
|--------|---------|-------------|
| `--file <path>` | — | `.flo` file to load on startup. Ignored (with warning) if already running — use `workflow open` instead |
| `--no-wait` | false | Skip readiness poll; return immediately after spawning |
| `--timeout <sec>` | 30 | Max seconds to wait for the API to become responsive |
| `--json` | false | Output raw JSON response |

```bash
floless start --json
floless start --file my-workflow.flo --json
floless start --timeout 60 --json
floless start --no-wait --json
```

Output: `{ "success": true, "data": { "pid": 12340, "port": 51432, "version": "1.0.0", "alreadyRunning": false } }`

Exit 0 when desktop is ready, 1 on timeout or launch failure.

---

### `floless close`

**Source:** `AppCommand.cs:CreateCloseCommand():259` | **Purpose:** Gracefully shut down the FloLess desktop. Deletes the port file on shutdown.

Options: `--json`

```bash
floless close --json
```

Output: `{ "success": true, "data": { "message": "FloLess desktop is shutting down." } }`

Exit 0 on success, 1 if desktop unreachable.

---

## Workflow subcommands

All workflow subcommands require the desktop to be running. Use `--workflow current` to target
the active diagram. Use `floless workflow list --json` to enumerate loaded workflow IDs.

---

### `floless workflow create`

**Source:** `WorkflowCommand.cs:49` | **Purpose:** Create a new `.flo` file from JSON input (validates first, then writes to disk).

Options: `--output <path>` (required), `--input <file>` (stdin if omitted — **hangs on TTY without**), `--name <string>`, `--description <string>`, `--json`

**Request body limit: 10 MB.**

```bash
floless workflow create --input workflow.json --output my.flo --json
cat workflow.json | floless workflow create --output my.flo --name "My Workflow" --json
```

Output: `{ "success": true, "data": { "valid": true, "nodeCount": 3, "connectionCount": 2 } }`

---

### `floless workflow validate`

**Source:** `WorkflowCommand.cs:78` | **Purpose:** Validate a `.flo` file for structural correctness without writing anything.

Arguments: `file` (required path to `.flo`)
Options: `--json`

**Request body limit: 10 MB.**

```bash
floless workflow validate my-workflow.flo --json
```

Output on valid: `{ "success": true, "data": { "valid": true, "nodeCount": 3, "connectionCount": 2 } }`
Error on invalid: `errorCode: invalid_workflow` with `errorWrapper.details.errors[]`

---

### `floless workflow info`

**Source:** `WorkflowCommand.cs:101` | **Purpose:** Show summary information about a `.flo` file (name, description, node/connection counts).

Arguments: `file` (required path to `.flo`)
Options: `--json`

```bash
floless workflow info my-workflow.flo --json
```

Output: `{ "success": true, "data": { "name": "My Workflow", "description": "...", "nodeCount": 5, "connectionCount": 4, "triggerCount": 1, "actionCount": 2 } }`

---

### `floless workflow list`

**Source:** `WorkflowCommand.cs:442` | **Purpose:** List all workflows currently loaded in the desktop.

Options: `--json`

```bash
floless workflow list --json
```

Output: `{ "success": true, "data": [{ "id": "wf-abc-123", "name": "My Workflow", "filePath": "C:\\...\\my.flo", "isActive": true, "isDirty": false }], "count": 1 }`

`isActive: true` = same workflow as `--workflow current`. Use `id` in other subcommands.

---

### `floless workflow nodes`

**Source:** `WorkflowCommand.cs:464` | **Purpose:** List all nodes in a loaded workflow (discovery step before node-specific operations).

Options: `--workflow <id>` (required), `--json`

```bash
floless workflow nodes --workflow current --json
floless workflow nodes --workflow wf-abc-123 --json
```

Output: `{ "success": true, "data": [{ "id": "node-xyz-789", "nodeType": "SmartNode", "title": "Process Beams", "x": 400.0, "y": 200.0, "componentId": null }], "count": 5 }`

---

### `floless workflow node-context`

**Source:** `WorkflowCommand.cs:492` | **Purpose:** Show full context for a node: configuration, code (Smart Nodes), prompt/model (Think Nodes), and connections.

Options: `--workflow <id>` (required), `--node <id>` (required), `--json`

```bash
floless workflow node-context --workflow current --node node-xyz-789 --json
```

Output: `{ "success": true, "data": { "id": "node-xyz-789", "nodeType": "SmartNode", "title": "Process Beams", "code": "...", "instructions": "...", "targetFramework": "net8.0", "inPorts": [...], "outPorts": [...] } }`

---

### `floless workflow add-node`

**Source:** `WorkflowCommand.cs:533` | **Purpose:** Add a new node to the loaded workflow.

Options:

| Option | Required | Description |
|--------|----------|-------------|
| `--workflow <id>` | Yes | `current` for active workflow |
| `--type <type>` | Yes | `SmartNode`, `ThinkNode`, `Trigger`, `Action`, `Condition`, `Path`, `Cluster`, `Input`, etc. Server validates against NodeTypeRegistry |
| `--title <string>` | No | Node title (defaults to NodeTypeRegistry default) |
| `--component-id <id>` | No | Required for `Trigger`/`Action` types — discover via `floless triggers --json` or `floless actions --json` |
| `--x <double>` | No | Canvas X coordinate (default: viewport center) |
| `--y <double>` | No | Canvas Y coordinate (default: viewport center) |
| `--json` | No | Output raw JSON response |

```bash
floless workflow add-node --workflow current --type SmartNode --title "Process Beams" --json
floless workflow add-node --workflow current --type Action --component-id tekla-get-beams --x 400 --y 200 --json
```

Output: `{ "success": true, "data": { "nodeId": "node-xyz-789", "type": "SmartNode", "display": "Process Beams", "x": 400.0, "y": 200.0 } }`

---

### `floless workflow delete-node`

**Source:** `WorkflowCommand.cs:572` | **Purpose:** Remove a node from the loaded workflow. Cascade-deletes all connections to/from the node. Supports undo in the desktop.

Options: `--workflow <id>` (required), `--node <id>` (required), `--json`

```bash
floless workflow delete-node --workflow current --node node-xyz-789 --json
```

Output: `{ "success": true, "data": { "nodeId": "node-xyz-789", "connectionsRemoved": 3 } }`

---

### `floless workflow connect`

**Source:** `WorkflowCommand.cs:615` | **Purpose:** Wire two nodes by source/target node ID and port index. Cycle detection and type compatibility enforced server-side.

Options: `--workflow <id>` (required), `--from <id>` (required), `--from-port <int>` (required, 0-based), `--to <id>` (required), `--to-port <int>` (required, 0-based), `--json`

```bash
floless workflow connect --workflow current --from node-abc --from-port 0 --to node-xyz --to-port 0 --json
```

Output: `{ "success": true, "data": { "connectionId": "conn-111-222", "from": "node-abc", "to": "node-xyz" } }`

Error on cycle: `errorCode: cycle_detected`

---

### `floless workflow disconnect`

**Source:** `WorkflowCommand.cs:660` | **Purpose:** Remove connections between two nodes. Idempotent — no-match returns `success: true` with `count: 0`. Without `--from-port`/`--to-port`, removes ALL edges between the nodes.

Options: `--workflow <id>` (required), `--from <id>` (required), `--to <id>` (required), `--from-port <int>` (optional), `--to-port <int>` (optional), `--json`

```bash
floless workflow disconnect --workflow current --from node-abc --to node-xyz --json
floless workflow disconnect --workflow current --from node-abc --from-port 0 --to node-xyz --to-port 0 --json
```

Output: `{ "success": true, "data": { "connectionsRemoved": 2 }, "count": 2 }`

---

### `floless workflow update-think-node`

**Source:** `WorkflowCommand.cs:717` | **Purpose:** Update a Think Node's configuration. PATCH semantics: omitted options leave fields unchanged; pass `""` to clear nullable string fields.

Options:

| Option | Required | Description |
|--------|----------|-------------|
| `--workflow <id>` | Yes | `current` for active workflow |
| `--node <id>` | Yes | Think Node ID to update |
| `--prompt-template <text>` | No | Prompt with `{variable}` placeholders. `""` clears. `"-"` reads stdin; `"@path"` reads file |
| `--system-prompt <text>` | No | System prompt / role description. `""` clears |
| `--model <id>` | No | Model ID (e.g., `claude-sonnet-4-20250514`). Cannot be cleared |
| `--temperature <float>` | No | 0.0–1.0. Cannot be cleared |
| `--response-format <fmt>` | No | `json`, `text`, or `markdown`. Cannot be cleared |
| `--caching <bool>` | No | Enable prompt caching. Cannot be cleared |
| `--max-input-tokens <int>` | No | Max input tokens. Cannot be cleared |
| `--max-output-tokens <int>` | No | Max output tokens. Cannot be cleared |
| `--input-schema-json <json>` | No | Input schema as JSON array. `""` clears |
| `--output-schema-json <json>` | No | Output schema as JSON array. `""` clears |
| `--json` | No | Output raw JSON response |

```bash
floless workflow update-think-node --workflow current --node node-think-1 \
  --prompt-template "Classify: {inputText}" --model claude-sonnet-4-20250514 \
  --temperature 0.2 --response-format json --json
```

Output: `{ "success": true, "data": { "nodeId": "node-think-1", "updated": true } }`

---

### `floless workflow export`

**Source:** `WorkflowCommand.cs:768` | **Purpose:** Export the loaded workflow as canonical `.flo` JSON. **Read-only snapshot** — does NOT update desktop's CurrentFilePath or dirty flag. Use `save-as` to persist changes.

Options: `--workflow <id>` (required), `--output <path>` (optional, stdout if omitted), `--json` (envelope instead of unwrapped .flo)

```bash
floless workflow export --workflow current --output snapshot.flo
floless workflow export --workflow current
floless workflow export --workflow current --json
```

---

### `floless workflow open`

**Source:** `WorkflowCommand.cs:797` | **Purpose:** Open a `.flo` file in the running desktop (headless File > Open). Replaces whatever is currently loaded.

**NEW — not in CONTEXT.md D-16's original 24-command list.**

Options: `--file <path>` (required), `--force` (discard unsaved changes without prompt), `--json`

```bash
floless workflow open --file my-workflow.flo --json
floless workflow open --file my-workflow.flo --force --json
```

Output: `{ "success": true, "data": { "filePath": "C:\\...\\my-workflow.flo", "name": "My Workflow" } }`

Error when dirty: `errorCode: conflict_dirty_workflow` — use `--force` or `floless workflow save` first.

---

### `floless workflow save`

**Source:** `WorkflowCommand.cs:820` | **Purpose:** Save the currently loaded workflow to its existing file path (headless Ctrl+S). Clears the dirty flag.

**NEW — not in CONTEXT.md D-16's original 24-command list.**

**Gotcha:** Fails with `errorCode: conflict_no_current_path` if the workflow is Untitled. Use `floless workflow save-as --output {path}` instead.

Options: `--json`

```bash
floless workflow save --json
```

Output: `{ "success": true, "data": { "filePath": "C:\\...\\my.flo", "saved": true } }`

---

### `floless workflow save-as`

**Source:** `WorkflowCommand.cs:842` | **Purpose:** Save the currently loaded workflow to a new file path (headless File > Save As). Updates desktop's CurrentFilePath and clears dirty flag.

**NEW — not in CONTEXT.md D-16's original 24-command list.**

**Distinction from `export`:** `save-as` updates desktop state (CurrentFilePath + dirty flag). `export` is a read-only snapshot that leaves desktop state untouched.

Options: `--output <path>` (required), `--json`

```bash
floless workflow save-as --output new-workflow.flo --json
```

Output: `{ "success": true, "data": { "filePath": "C:\\...\\new-workflow.flo", "saved": true } }`

---

### `floless workflow run`

**Source:** `WorkflowCommand.cs:1970` | **Purpose:** Start workflow execution in the desktop (headless Play button). Operates on the currently loaded workflow — use `floless workflow open` first if needed. No `--workflow` option.

Options: `--wait` (block until fire-once completion; 5-minute server cap; returns immediately with warning for daemon/trigger-based workflows), `--json`

```bash
floless workflow run --json
floless workflow run --wait --json
```

Output (non-blocking): `{ "success": true, "data": { "started": true, "waited": false, "nodeCount": 5 } }`
Output (--wait): `{ "success": true, "data": { "started": true, "waited": true, "nodeCount": 5 } }`

---

### `floless workflow stop`

**Source:** `WorkflowCommand.cs:2049` | **Purpose:** Stop the currently running workflow in the desktop (headless Stop button). No `--workflow` option.

Options: `--json`

```bash
floless workflow stop --json
```

Output: `{ "success": true, "data": { "stopped": true } }`

---

## Common error envelopes

Six most-encountered error codes across all commands:

```json
{ "success": false, "errorCode": "not_found_node", "errorWrapper": { "code": "not_found_node", "message": "Node 'abc-123' not found in workflow.", "details": { "nodeId": "abc-123" } } }
```

```json
{ "success": false, "errorCode": "invalid_workflow", "errorWrapper": { "code": "invalid_workflow", "message": "Workflow validation failed.", "details": { "errors": ["..."] } } }
```

```json
{ "success": false, "errorCode": "payload_too_large", "errorWrapper": { "code": "payload_too_large", "message": "Request body exceeds limit.", "details": { "limitBytes": 1048576 } } }
```

```json
{ "success": false, "errorCode": "length_required", "errorWrapper": { "code": "length_required", "message": "Content-Length header is required for this endpoint." } }
```

```json
{ "success": false, "errorCode": "unauthorized", "errorWrapper": { "code": "unauthorized", "message": "Invalid or expired bearer token. Run 'floless start' to refresh the port file." } }
```

```json
{ "success": false, "errorCode": "desktop_not_reachable", "errorWrapper": { "code": "desktop_not_reachable", "message": "HTTP request to FloLess desktop timed out after 30 seconds." } }
```

---

## The compile gotcha

Repeated here because agents often load this file directly without reading `SKILL.md`.

`success: true` on `floless compile` means only that the API call reached the desktop.
Always check `data.compiled` (boolean) for the actual compilation result.

```
floless compile exits 0?
  No  → API error. Check errorCode.
  Yes → data.compiled == true?  → compilation OK; data.nodeUpdated if --node was used
                   == false? → compilation failed; read data.diagnostics[]
```

`data.diagnostics[]` fields: `severity` (Error/Warning), `id` (e.g., CS0246), `message`, `line`, `column`.

```bash
RESULT=$(floless compile --code MyNode.cs --workflow current --node {nodeId} --json)
if [ "$(echo "$RESULT" | jq -r '.success')" = "true" ] && \
   [ "$(echo "$RESULT" | jq -r '.data.compiled')" = "true" ]; then
  echo "OK"
else
  echo "$RESULT" | jq -r '.data.diagnostics[] | "\(.line):\(.column) \(.severity) \(.id): \(.message)"'
fi
```
