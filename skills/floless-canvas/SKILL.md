---
name: floless-canvas
description: Design readable FloLess workflow canvas layouts. Use when positioning nodes, understanding port index semantics, or debugging unreadable node arrangements. Teaches top-to-bottom flow, 200px vertical stepping with 300px horizontal offset for parallel branches, and the X/Y coordinate system for Trigger/Action/SmartNode/ThinkNode/Condition/Display node types.
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.1.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read
---

# floless-canvas

Canvas layout and node positioning skill for FloLess workflow design. Use this skill when designing
workflows that humans will review, positioning nodes on the visual canvas, troubleshooting unreadable
layouts, or understanding which port index carries which data between node types.

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

## When to use this skill

Use this skill in these scenarios:

- **Designing a workflow humans will review** — position nodes so the layout reads top-to-bottom and reviewers can trace the data flow downward without confusion.
- **Positioning nodes on the canvas** — when adding nodes via `floless workflow add-node --x N --y N`, use the coordinate rules here to avoid overlapping nodes or cluttered layouts.
- **Troubleshooting unreadable layouts** — all nodes at (0,0), nodes overlapping, or left-to-right flow are common layout bugs. The common mistakes section covers all of them.
- **Understanding port index semantics** — before wiring connections with `floless workflow connect`, verify which port index carries which data for each node type.
- **Generating workflow JSON programmatically** — use the X/Y and port index facts here to produce valid, human-readable workflow JSON from scratch.

## Node coordinate system

FloLess uses a device-independent pixel coordinate system with these rules:

- **Origin:** (0, 0) is the top-left of the canvas. **Do not place nodes there** — they end up
  in the corner with all the empty canvas to the right and below, which looks broken.
- **Canvas size:** the default canvas is 2000 × 1500 device-independent pixels. The viewport
  centers around roughly (1000, 750) when a fresh workflow opens.
- **Y axis (primary flow axis):** increases downward. Downstream nodes have higher Y values.
- **X axis (branch axis):** increases rightward. Use X to separate parallel branches.
- **Units:** device-independent pixels (DIPs). No scaling factor to apply.
- **Starting position:** place the first node (always a Trigger) **near the canvas centerline**,
  not at the origin. For a typical 2000 × 1500 canvas, start the Trigger at roughly
  `(900, 300)` — horizontally centered (X ≈ canvasWidth/2 − 100 to account for ~200px node
  width), with Y near the upper third so the flow has room to extend downward without
  scrolling.

Canvas settings (zoom, viewport offset) are cosmetic and do not affect the stored X/Y coordinates.
The coordinates stored in the workflow JSON are absolute canvas positions, independent of zoom level.

## Port index semantics

Each node type has a fixed number of input and output ports. Connections reference ports by zero-based
index. The table below is the authoritative reference for the 6 primary node types.

| Node type     | Input ports | Output ports | Input port meanings          | Output port meanings                                       |
|---------------|-------------|--------------|------------------------------|------------------------------------------------------------|
| Trigger       | 0           | 1            | (none)                       | 0 = trigger event payload                                  |
| Action        | 1           | N (1+)       | 0 = upstream data            | 0 = action result; 1+ = additional outputs (multi-output actions) |
| SmartNode     | 1           | 1            | 0 = JSON input               | 0 = JSON output                                            |
| ThinkNode     | 1           | 1            | 0 = LLM input context        | 0 = LLM output                                             |
| Condition     | 1           | 2            | 0 = value to test            | 0 = true branch; 1 = false branch                          |
| Display       | 1           | 0            | 0 = value to show            | (none — terminal node)                                     |

**Connection format in workflow JSON:**
```json
{
  "SourceNodeId": "{sourceGuid}",
  "SourcePortIndex": 0,
  "TargetNodeId": "{targetGuid}",
  "TargetPortIndex": 0
}
```

Use GUID values for `{sourceGuid}` and `{targetGuid}`. Discover existing node GUIDs via
`floless workflow nodes --workflow current --json`.

**Key rules:**
- Trigger nodes have **no input ports** — never write a connection targeting a Trigger node.
- Display nodes have **no output ports** — never write a connection sourcing from a Display node.
- Condition port index 0 = true branch, port index 1 = false branch. Never reverse this.
- For extended node types (Input, Iterator, Aggregator, DataProcessing, Cluster, Connector), query
  `floless schema --type workflow --json` for the authoritative per-type port counts, or see
  [references/layout-guide.md](references/layout-guide.md) for the extended type table.

## Layout best practices

Apply these deterministic layout rules to produce readable workflows:

### Vertical stepping (top-to-bottom flow) — primary axis

```
y_{n+1} = y_n + 200
```

Place each downstream node 200px below its predecessor. Linear flows read cleanly at this spacing
and accommodate the tallest standard nodes (Text Panel / MultilineText is ~200px tall). Do not
compress below 150px (nodes overlap visually) or expand above 300px (excessive whitespace).

### Horizontal offset (parallel branches) — secondary axis

```
x_branch = x_parent + 300
```

Use X to separate parallel branches, Condition outputs, and fan-out targets. A 300px horizontal
offset keeps branches visually distinct even when nodes are ~250–400px wide (e.g., Text Panel is
400px by default).

### Condition branches

The Condition node has two outputs (port 0 = true, port 1 = false). Both children sit one row below:

- Place the true branch at `(x_parent - 150, y_parent + 200)`.
- Place the false branch at `(x_parent + 150, y_parent + 200)`.
- Port index 0 is **always** the true branch and port index 1 is **always** the false branch,
  regardless of which side you placed them on. Never reverse the port-to-meaning mapping.
- If the false branch is the primary/expected path, swap the horizontal positions for visual
  priority — but keep the port indexes fixed.

### Display terminators

- Always place Display nodes at the **bottommost Y** of their branch.
- X matches the upstream node in the branch (keep the column straight).
- Never place a Display node in the middle of a flow — it is a terminal node with no output ports.

### Starting position — do not place at (0, 0)

Place the Trigger near the **canvas centerline**, not at the origin. For the default
2000 × 1500 canvas, start the Trigger at approximately `(900, 300)`:

- `X = 900` ≈ `canvasWidth/2 − nodeWidth/2` (≈ 1000 − 100). The trigger sits horizontally
  centered, with the rest of the flow stacking below in a clean column.
- `Y = 300` is near the upper third of the canvas. A linear flow can extend downward by
  multiples of 200px (`y = 300, 500, 700, 900, …`) without spilling off-canvas — the canvas
  comfortably accommodates 6+ vertically-stacked nodes from this anchor.

All other nodes are positioned relative to this anchor: downstream nodes step Y by +200;
parallel branches spread X by ±150 around the parent column.

## Title and Description fields — do not override Title

The Node JSON has three text fields: `Title`, `Subtitle`, and `Description`. They are NOT
interchangeable, and AI-authored workflows commonly misuse them.

| Field | Owned by | Purpose | When AI should set it |
|---|---|---|---|
| `Title` | The component | Display title shown on the node, defaulted from the component definition (e.g. "Folder Watcher", "Send Email"). | **Never override.** Omit the field entirely — FloLess fills it from the `NodeTypeRegistry` default for the chosen `ComponentId`. Overriding produces a node whose label no longer matches its component, confusing reviewers and breaking visual recognition. |
| `Subtitle` | The component (rare) | Optional secondary line below the title. | **Never override** unless the user explicitly asks. |
| `Description` | The user / author | A short user-editable badge rendered above the node. This is the field for "what this instance does in this workflow". | **This is where AI annotations belong.** Use it for purpose-specific text like `"Watch input/ for .j<N>"` or `"Sentinelize"` — anything that distinguishes this instance from a generic component. |

```json
// CORRECT
{
  "Id": "trigger-1",
  "NodeType": "Trigger",
  "ComponentId": "folder-watcher",
  "Description": "Watch input/ for new .j<N> files",
  "X": 900, "Y": 300,
  "Config": { ... }
}

// WRONG — Title overridden, no Description
{
  "Id": "trigger-1",
  "NodeType": "Trigger",
  "ComponentId": "folder-watcher",
  "Title": "Watch input/ for new .j<N> files",   // ← never do this
  "X": 900, "Y": 300,
  "Config": { ... }
}
```

Same rule applies to `floless workflow add-node`: do **not** pass `--title`. The CLI's own
help describes it as "Optional node title (defaults to NodeTypeRegistry default)" — that
default is what the user expects to see. If you need to convey what this instance does,
include it in the workflow's overall design or in `Description` (set in a follow-up
`update-node` if/when the CLI exposes that, or directly in the JSON for Flow A authoring).

## Worked example

A 5-node workflow: Trigger → Action → Condition → Display (true) + Display (false).

| Node        | Type      | x    | y   | Notes                                                    |
|-------------|-----------|------|-----|----------------------------------------------------------|
| Trigger     | Trigger   | 900  | 300 | Anchor near canvas centerline                            |
| Action      | Action    | 900  | 500 | 200px below Trigger                                      |
| Condition   | Condition | 900  | 700 | 200px below Action                                       |
| Display-T   | Display   | 750  | 900 | True branch: 150px left of parent column, 200px below    |
| Display-F   | Display   | 1050 | 900 | False branch: 150px right of parent column, 200px below  |

Connections:
- Trigger(out:0) → Action(in:0)
- Action(out:0) → Condition(in:0)
- Condition(out:0) → Display-T(in:0)  ← true branch (port 0)
- Condition(out:1) → Display-F(in:0)  ← false branch (port 1)

This produces a clean top-to-bottom layout with clear branch separation at the Condition node.

## Common mistakes

Avoid these anti-patterns that AI agents commonly produce:

**1. Anchoring at (0, 0)**
Placing the Trigger at the canvas origin parks the whole flow in the top-left corner with all
the empty canvas to the right and below. The user opens the workflow and sees a node squashed
against the chrome. Fix: anchor the Trigger near the centerline, around `(900, 300)` for a
2000 × 1500 canvas, and step downward from there.

**2. All nodes at (0, 0)**
Nodes overlap completely and the canvas shows a single unreadable stack. Fix: apply the 200px
vertical stepping rule starting from the centered Trigger anchor.

**3. Left-to-right flow**
Increasing X values along the linear data path (x=900, x=1100, x=1300) produces a flow that
reads sideways. FloLess canvases are designed for top-to-bottom reading; horizontal flows
contradict the canonical direction. Fix: increase Y (not X) as the flow progresses downstream.

**4. Inconsistent spacing**
Mixing 50px, 300px, and 200px vertical gaps makes the layout look chaotic. Fix: use exactly
200px vertical for linear flow and 300px horizontal between parallel branches.

**5. Display terminator in the middle**
Placing a Display node at y=500 with an Action at y=700 is structurally invalid — Display has
no output ports. Fix: always place Display at the bottommost Y of the branch.

**6. Condition branches at the same X**
Both true and false branches at the parent X overlap. Fix: spread them ±150px around the
parent column.

**7. Overriding `Title` with custom text**
AI agents commonly try to label what a node does by setting `Title` to something descriptive
like `"Watch output/ for *.png"`. This breaks the visual contract — the on-node label should
match the component's default name (`Folder Watcher`, `Send Email`) so reviewers can recognize
node types at a glance. Fix: omit `Title` entirely (let the `NodeTypeRegistry` default fill
in), and put your custom text in `Description` instead. See the
[Title and Description section](#title-and-description-fields--do-not-override-title) for
the exact field semantics.

**8. Missing port indexes in connection JSON**
Omitting `SourcePortIndex` or `TargetPortIndex` fields causes the connection to fail. Fix:
always include both port index fields, defaulting to 0 when there is only one port.

## Progressive disclosure

This SKILL.md covers the 6 primary node types and the core layout rules. For the exhaustive
reference including all 14 NodeType values, 4 canonical layout patterns with full JSON snippets,
and per-type worked examples, see:

- [Layout guide (references/layout-guide.md)](references/layout-guide.md)

Load the layout guide when you need: the full NodeType port count table, fan-out/fan-in examples,
Aggregator convergence patterns, or the exact CLI command syntax for setting node positions.

## Cross-skill links

- **[floless-cli](../floless-cli/SKILL.md)** — Port file discovery, connection pattern, and the
  Stripe-style error envelope. Read this first if `floless` CLI commands are failing.
- **[floless-workflows](../floless-workflows/SKILL.md)** — Flow A (build from scratch) and Flow B
  (augment loaded workflow) including `floless workflow add-node --x N --y N` for setting canvas
  positions and `floless workflow connect` for wiring port indexes.
- **[floless-overview](../floless-overview/SKILL.md)** — Conceptual entry point: what FloLess is,
  the full node taxonomy, and which skill to use for each task.
