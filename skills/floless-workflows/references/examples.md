# Workflow examples

These examples cover the full range of workflow authoring patterns: minimal Flow A,
complex Flow A with variable templating, multi-action variable passing, and a Flow B
augmentation trace. All JSON is valid and round-trippable with the FloLess serializer.

**Convention:** `{variable}` is a prose placeholder (replace it). `{{variable}}` inside
JSON string values is runtime template syntax (the engine evaluates it at execution time).

---

## Example 1: Minimal — Trigger → Display

The smallest valid workflow: one Trigger, one Display, one connection.
Demonstrates the required fields and the simplest possible topology.

```json
{
  "Name": "Minimal Workflow",
  "Version": "1.0.0",
  "Nodes": [
    {
      "Id": "node-trigger-1",
      "NodeType": "Trigger",
      "Title": "Excel Cell Changed",
      "ComponentId": "excel-cell-changed",
      "X": 100,
      "Y": 200,
      "Config": {
        "filePath": "C:\\Data\\book.xlsx",
        "sheetName": "Sheet1",
        "cellAddress": "A1"
      }
    },
    {
      "Id": "node-display-1",
      "NodeType": "Display",
      "Title": "Result",
      "X": 450,
      "Y": 200
    }
  ],
  "Connections": [
    {
      "SourceNodeId": "node-trigger-1",
      "SourcePortIndex": 0,
      "TargetNodeId": "node-display-1",
      "TargetPortIndex": 0
    }
  ]
}
```

**Field notes:**
- `Version` and `Name` are required — never omit them.
- `ComponentId` is required for Trigger and Action nodes. Use `floless triggers --json` to
  discover valid IDs.
- `Config` holds component-specific configuration (from the component's parameter definitions).
- Display has no outputs — it is always a terminal node.
- `SourcePortIndex` / `TargetPortIndex` default to 0; they can be omitted when 0.

**Create this workflow:**

```bash
floless workflow validate minimal.json --json
floless workflow create --input minimal.json --output minimal.flo --json
```

---

## Example 2: Excel to Tekla with Condition

A trigger fires on Excel cell change. A Condition node branches: if the cell value is
above a threshold, create a Tekla beam; otherwise, log that the step was skipped.
Variable templating passes `{{trigger.cellValue}}` into the Condition expression.

```json
{
  "Name": "Excel to Tekla with Condition",
  "Version": "1.0.0",
  "Description": "Route Excel cell changes to Tekla or to a skip log based on value threshold",
  "Nodes": [
    {
      "Id": "trigger-excel",
      "NodeType": "Trigger",
      "Title": "Excel Cell Changed",
      "ComponentId": "excel-cell-changed",
      "X": 100,
      "Y": 200,
      "Config": {
        "filePath": "C:\\Data\\structural.xlsx",
        "sheetName": "Loads",
        "cellAddress": "B2"
      }
    },
    {
      "Id": "condition-threshold",
      "NodeType": "Condition",
      "Title": "Value > 100?",
      "X": 350,
      "Y": 200,
      "Config": {
        "Expression": "{{trigger.cellValue}} > 100"
      }
    },
    {
      "Id": "action-create-beam",
      "NodeType": "Action",
      "Title": "Create Tekla Beam",
      "ComponentId": "tekla-create-beam",
      "X": 600,
      "Y": 100,
      "Config": {
        "profile": "HEA200",
        "length": "{{trigger.cellValue}}",
        "materialGrade": "S355"
      }
    },
    {
      "Id": "action-log-skip",
      "NodeType": "Action",
      "Title": "Log Skipped",
      "ComponentId": "log",
      "X": 600,
      "Y": 300,
      "Config": {
        "Message": "Value {{trigger.cellValue}} below threshold — skipped"
      }
    },
    {
      "Id": "display-result",
      "NodeType": "Display",
      "Title": "Result",
      "X": 850,
      "Y": 200
    }
  ],
  "Connections": [
    {
      "SourceNodeId": "trigger-excel",
      "SourcePortIndex": 0,
      "TargetNodeId": "condition-threshold",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "condition-threshold",
      "SourcePortIndex": 0,
      "TargetNodeId": "action-create-beam",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "condition-threshold",
      "SourcePortIndex": 1,
      "TargetNodeId": "action-log-skip",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "action-create-beam",
      "SourcePortIndex": 0,
      "TargetNodeId": "display-result",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "action-log-skip",
      "SourcePortIndex": 0,
      "TargetNodeId": "display-result",
      "TargetPortIndex": 0
    }
  ]
}
```

**Key patterns:**
- `SourcePortIndex: 0` on Condition = **True** branch; `SourcePortIndex: 1` = **False** branch.
- `{{trigger.cellValue}}` in a Config string is evaluated at execution time — use double braces.
- Two action branches both connect to the same Display node — that is valid (Display accepts
  multiple incoming connections; it renders whichever fires last).

---

## Example 3: Multi-action variable passing

A folder-watcher trigger fires when a new file appears. Three chained actions read the
file, summarize it with a ThinkNode, then email the summary. Each action passes its output
to the next via `{{actionTitle.result}}` template syntax.

```json
{
  "Name": "File Summarizer and Emailer",
  "Version": "1.0.0",
  "Description": "Watch a folder, summarize new files with AI, email the summary",
  "Nodes": [
    {
      "Id": "trigger-folder",
      "NodeType": "Trigger",
      "Title": "New File Detected",
      "ComponentId": "folder-watcher",
      "X": 50,
      "Y": 200,
      "Config": {
        "folderPath": "C:\\Incoming\\Reports",
        "filePattern": "*.pdf"
      }
    },
    {
      "Id": "action-read",
      "NodeType": "Action",
      "Title": "Read File",
      "ComponentId": "file-read",
      "X": 300,
      "Y": 200,
      "Config": {
        "filePath": "{{trigger.filePath}}"
      }
    },
    {
      "Id": "think-summarize",
      "NodeType": "ThinkNode",
      "Title": "Summarize",
      "X": 550,
      "Y": 200,
      "ThinkNodePromptTemplate": "Summarize the following document in 3 bullet points:\n\n{{Read File.result}}",
      "ThinkNodeSelectedModel": "claude-sonnet-4-20250514",
      "ThinkNodeTemperature": 0.3,
      "ThinkNodeResponseFormat": "text"
    },
    {
      "Id": "action-email",
      "NodeType": "Action",
      "Title": "Send Email",
      "ComponentId": "email-send",
      "X": 800,
      "Y": 200,
      "Config": {
        "to": "team@company.com",
        "subject": "New Report Summary: {{trigger.fileName}}",
        "body": "{{Summarize.result}}"
      }
    },
    {
      "Id": "display-done",
      "NodeType": "Display",
      "Title": "Done",
      "X": 1050,
      "Y": 200
    }
  ],
  "Connections": [
    {
      "SourceNodeId": "trigger-folder",
      "SourcePortIndex": 0,
      "TargetNodeId": "action-read",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "action-read",
      "SourcePortIndex": 0,
      "TargetNodeId": "think-summarize",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "think-summarize",
      "SourcePortIndex": 0,
      "TargetNodeId": "action-email",
      "TargetPortIndex": 0
    },
    {
      "SourceNodeId": "action-email",
      "SourcePortIndex": 0,
      "TargetNodeId": "display-done",
      "TargetPortIndex": 0
    }
  ]
}
```

**Key patterns:**
- `{{trigger.filePath}}` and `{{trigger.fileName}}` — fields from the folder-watcher trigger's
  output schema. Use `floless node-context` to inspect what fields a trigger exposes.
- `{{Read File.result}}` — references the output of the node whose **Title** is `"Read File"`.
  The template engine resolves by title, not by `Id`. Keep titles unique within a workflow.
- `{{Summarize.result}}` — the ThinkNode's text output passed into the email body.
- ThinkNode fields (`ThinkNodePromptTemplate`, etc.) are inline in the node object — no
  separate `Config` key.

---

## Example 4: Flow B augmentation trace

Starting from Example 1 (Trigger → Display, already loaded in the desktop), insert a
SmartNode between them using the Flow B CLI sequence.

**Prerequisite:** Example 1's workflow is open in the FloLess desktop.

**Step 1 — Confirm the workflow is loaded and note node IDs:**

```bash
floless workflow list --json
floless workflow nodes --workflow current --json
# Output includes node IDs — note trigger ID (call it "trigger-id") and
# display ID (call it "display-id")
```

**Step 2 — Add the SmartNode:**

```bash
floless workflow add-node --workflow current \
  --type SmartNode \
  --title "Process Data" \
  --x 280 --y 200 --json
# Response: { "success": true, "data": { "nodeId": "smart-id-generated-by-server" } }
# Note the new node's ID — call it "smart-id"
```

**Step 3 — Remove the direct Trigger → Display connection:**

```bash
floless workflow disconnect --workflow current \
  --from {trigger-id} --to {display-id} --json
# Idempotent: returns success even if the connection was already gone
```

**Step 4 — Wire Trigger → SmartNode:**

```bash
floless workflow connect --workflow current \
  --from {trigger-id} --from-port 0 \
  --to {smart-id} --to-port 0 --json
```

**Step 5 — Wire SmartNode → Display:**

```bash
floless workflow connect --workflow current \
  --from {smart-id} --from-port 0 \
  --to {display-id} --to-port 0 --json
```

**Step 6 — Verify the topology:**

```bash
floless workflow export --workflow current --json
# Returns the full .flo JSON; confirm Nodes has 3 entries and Connections has 2
```

**Step 7 — Save to disk:**

```bash
# If the workflow already has a file path:
floless workflow save --json

# If Untitled or saving to a new path:
floless workflow save-as --output augmented-workflow.flo --json
```

---

## Tips for AI agents

- **Always include `Version`** — missing Version is the most common validation failure.
  Use `"1.0.0"` unless you have a specific reason for another value.
- **Set positions with `--x`/`--y`** — avoid placing all nodes at (0, 0). A top-to-bottom
  layout with 200 px vertical stepping (and 300 px horizontal offset between parallel branches)
  is readable in the desktop. See the `floless-canvas` skill for the full layout guide.
- **Prefer SmartNode over ThinkNode for static logic** — SmartNode C# code runs fast with no
  LLM latency or cost. Use ThinkNode when the task genuinely requires natural language
  understanding at execution time. See the `floless-smart-nodes` skill for the
  Smart-vs-Think decision guide.
- **Validate before `workflow create`** — run `floless workflow validate draft.json --json`
  first. Validation errors include per-field details that make the fix obvious.
- **Use GUIDs for node IDs** — human-readable IDs like `"trigger-1"` work but are fragile in
  Flow B (they may collide with auto-generated IDs). Generate proper GUIDs:
  `[System.Guid]::NewGuid().ToString()` in PowerShell, or `uuidgen` in bash.
- **Check `{{variable}}` references match upstream output schemas** — use
  `floless workflow node-context --workflow current --node {nodeId} --json` to see what
  output fields a node exposes before referencing them in downstream Config values.
- **`workflow export` ≠ `workflow save`** — export is a read-only snapshot that does not
  update the desktop's current file path. Use `save` or `save-as` to persist.
