# Workflow JSON schema

The `.flo` file is UTF-8 JSON. All property names are **PascalCase** — this is required by the
FloLess serializer. The authoritative live schema is served by the CLI:

```bash
floless schema --type workflow --json
```

---

## Top-level structure

```json
{
  "Name":        "string (required)",
  "Version":     "string (required, e.g. \"1.0.0\")",
  "Nodes":       "Node[] (required, min 1 element)",
  "Connections": "Connection[] (required, may be empty)",
  "Description": "string (optional)",
  "Settings":    "object (optional, per-workflow settings overrides)",
  "ZoomLevel":   "number (optional, canvas zoom, default 1.0)",
  "PanX":        "number (optional, canvas horizontal pan offset)",
  "PanY":        "number (optional, canvas vertical pan offset)",
  "CreatedAt":   "string (optional, ISO 8601)",
  "ModifiedAt":  "string (optional, ISO 8601)",
  "Author":      "string (optional)"
}
```

**Required fields:** `Version`, `Name`, `Nodes`, `Connections`

`Settings` is an optional object that overrides global per-workflow settings (e.g. model keys,
execution timeout). Omit or set to `{}` to inherit global settings.

---

## Nodes array

Each element in `Nodes` represents one node on the canvas.

### Common node fields

| Field | Type | Required | Description |
|---|---|---|---|
| `Id` | string | yes | Unique identifier within this workflow. GUID format recommended. Must be non-empty and unique. |
| `NodeType` | string | yes | Node category — see NodeType catalog below. |
| `Title` | string | no | Display title on the node card. Defaults to the NodeType default when omitted. |
| `X` | number | no | Horizontal canvas coordinate (pixels, left = 0). |
| `Y` | number | no | Vertical canvas coordinate (pixels, top = 0). |
| `Subtitle` | string | no | Secondary label below the title. |
| `Description` | string | no | User note displayed as a badge above the node. |
| `IsEnabled` | boolean | no | Whether the node participates in execution. Default `true`. |
| `ComponentId` | string | no | Component catalog ID (required for Trigger and Action nodes). |
| `Config` | object | no | Key-value configuration map for Trigger/Action parameters. |

### Trigger / Action node extras

Trigger and Action nodes use `ComponentId` + `Config`:

```json
{
  "Id": "trigger-1",
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
}
```

Discover valid `ComponentId` values:

```bash
floless triggers --json --provider excel
floless actions --json --provider tekla
```

### SmartNode extras

SmartNode executes AI-generated C# code. Include at minimum `SmartNodeInstructions`; the desktop
generates `SmartNodeGeneratedCode` when you open the workflow.

| Field | Type | Description |
|---|---|---|
| `SmartNodeInstructions` | string | Natural language instructions for AI code generation. |
| `SmartNodeGeneratedCode` | string | AI-generated C# code. Leave empty for new nodes — FloLess populates this. |
| `SmartNodeGenerationState` | string | `NotGenerated` \| `Generating` \| `Ready` \| `Stale` \| `Error` \| `Modified`. Use `NotGenerated` for new nodes. |
| `SmartNodeSelectedModel` | string | AI model for generation (e.g., `claude-sonnet-4-20250514`). Null uses user default. |
| `SmartNodeSoftwareVersion` | string | Target software version (e.g., `2025`) for compilation references. |
| `SmartNodeTargetFramework` | string | `".NET Core"` or `".NET Framework 4.8"`. |
| `SmartNodeRolePrompt` | string | Optional AI persona/role prompt. |
| `SmartNodeInputSchema` | string | Input field schema serialized as JSON string. |
| `SmartNodeOutputSchema` | string | Output field schema serialized as JSON string. |

Deep dive: see the `floless-smart-nodes` skill.

### ThinkNode extras

ThinkNode calls an LLM per execution. The CLI `update-think-node` command (A4) writes these
fields using PATCH semantics (omit fields you do not want to change).

**Note:** In `.flo` JSON these are serialized properties (e.g., `ThinkNodePromptTemplate`).
The CLI `update-think-node` command uses VM-style option names (`--prompt-template`,
`--model`, etc.) that are different from the JSON property names. Do not conflate the two.

| Field | Type | Description |
|---|---|---|
| `ThinkNodePromptTemplate` | string | Prompt template with `{{variable}}` placeholders (runtime-evaluated). |
| `ThinkNodeSystemPrompt` | string | System prompt / role description. |
| `ThinkNodeSelectedModel` | string | Model identifier (e.g., `claude-sonnet-4-20250514`). |
| `ThinkNodeTemperature` | number | 0.0–1.0. `0.1` = Precise, `0.5` = Balanced, `0.9` = Creative. |
| `ThinkNodeResponseFormat` | string | `json` \| `text` \| `markdown`. |
| `ThinkNodeIsCachingEnabled` | boolean | Enable prompt caching. |
| `ThinkNodeMaxInputTokens` | integer | Max input tokens. |
| `ThinkNodeMaxOutputTokens` | integer | Max output tokens. |
| `ThinkNodeInputSchemaJson` | string | Input schema serialized as JSON string. |
| `ThinkNodeOutputSchemaJson` | string | Output schema serialized as JSON string. |

Deep dive: see the `floless-think-nodes` skill.

---

## Connections array

Each element represents a directed edge between two node ports.

```json
{
  "SourceNodeId":    "string (required) — Id of the upstream node",
  "SourcePortIndex": "integer (default 0) — output port index on the source",
  "TargetNodeId":    "string (required) — Id of the downstream node",
  "TargetPortIndex": "integer (default 0) — input port index on the target"
}
```

Both `SourceNodeId` and `TargetNodeId` must reference an `Id` that exists in `Nodes`.
Port indices are 0-based.

---

## Port index semantics

Most nodes have a single input port (index 0) and a single output port (index 0).
Exceptions:

| NodeType | Input ports | Output ports | Notes |
|---|---|---|---|
| Trigger | 0 | 1 (index 0) | Triggers have no input — they start execution |
| Action | 1 (index 0) | 1 (index 0) | Standard single in / single out |
| SmartNode | 1+ (index 0+) | 1+ (index 0+) | Port count matches declared schema |
| ThinkNode | 1+ (index 0+) | 1+ (index 0+) | Port count matches declared schema |
| Condition | 1 (index 0) | 2 — True (0), False (1) | Route based on boolean expression |
| Path | 1 (index 0) | N (index 0..N-1) | Route based on N-way match |
| Display | 1 (index 0) | 0 | Terminal node — no outputs |
| Input | 0 | 1 (index 0) | User input node — no upstream |

For the full visual layout guide and exact port coordinates: see the `floless-canvas` skill.

---

## NodeType catalog

Valid values for the `NodeType` field (case-sensitive in the serializer, case-insensitive in
CLI options):

| NodeType | Purpose | Requires ComponentId |
|---|---|---|
| `Trigger` | Starts the workflow on an event | yes |
| `Action` | Executes an operation | yes |
| `Condition` | Branches on a boolean expression | no |
| `Path` | N-way routing | no |
| `SmartNode` | Runs AI-generated C# code | no |
| `ThinkNode` | Calls an LLM per execution | no |
| `Display` | Shows output in the canvas | no |
| `Input` | Accepts user-supplied data | no |
| `Script` | Runs an embedded script | no |
| `Script Action` | Script in action position | no |
| `Script Condition` | Script in condition position | no |
| `Script Trigger` | Script in trigger position | no |
| `DataProcessing` | Data transformation node | no |
| `Iterator` | Loops over a collection | no |
| `Aggregator` | Aggregates inputs | no |
| `Cluster` | Groups nodes visually | no |
| `CustomComponent` | User-defined component | varies |

Use `floless nodes --json` to get the live-verified list from the running desktop.

---

## Validation rules recap

Run `floless workflow validate <file> --json` to check these programmatically.

| Rule | Detail |
|---|---|
| `Version` required | Must be present and non-empty |
| `Name` required | Must be present and non-empty |
| `Nodes` non-empty | At least 1 node |
| Exactly 1 Trigger | Workflow cannot have 0 or 2+ Trigger nodes |
| Unique node IDs | All `Id` values in `Nodes` must be distinct and non-empty |
| Valid `NodeType` | Must appear in the NodeType catalog above |
| Connections reference existing nodes | Both `SourceNodeId` and `TargetNodeId` must exist in `Nodes` |
| No cycles | The connection graph must be a DAG (directed acyclic graph) |

---

## Cross-reference to the live schema

The schema above is derived from the `BuildWorkflowSchema()` implementation in
`src/FloLess/Core/Services/CliApi/CliApiRoutes.cs`. It may gain new fields in future
CLI releases. Always treat the CLI-served schema as authoritative:

```bash
floless schema --type workflow --json
```
