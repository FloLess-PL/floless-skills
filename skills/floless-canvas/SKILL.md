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

- **Origin:** (0, 0) is the top-left of the canvas.
- **Y axis (primary flow axis):** increases downward. Downstream nodes have higher Y values.
- **X axis (branch axis):** increases rightward. Use X to separate parallel branches.
- **Units:** device-independent pixels (DIPs). No scaling factor to apply.
- **Starting position:** place the first node (always a Trigger) at x=0, y=0.

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

### Starting origin

Always start with the Trigger node at x=0, y=0. All other nodes are positioned relative to this
anchor using the stepping rules above. Downstream nodes go below; parallel branches spread sideways.

## Worked example

A 5-node workflow: Trigger → Action → Condition → Display (true) + Display (false).

| Node        | Type      | x    | y   | Notes                                         |
|-------------|-----------|------|-----|-----------------------------------------------|
| Trigger     | Trigger   | 0    | 0   | Start at origin                               |
| Action      | Action    | 0    | 200 | 200px below Trigger                           |
| Condition   | Condition | 0    | 400 | 200px below Action                            |
| Display-T   | Display   | -150 | 600 | True branch: offset 150px left, 200px below   |
| Display-F   | Display   | 150  | 600 | False branch: offset 150px right, 200px below |

Connections:
- Trigger(out:0) → Action(in:0)
- Action(out:0) → Condition(in:0)
- Condition(out:0) → Display-T(in:0)  ← true branch (port 0)
- Condition(out:1) → Display-F(in:0)  ← false branch (port 1)

This produces a clean top-to-bottom layout with clear branch separation at the Condition node.

## Common mistakes

Avoid these anti-patterns that AI agents commonly produce:

**1. All nodes at (0,0)**
Nodes overlap completely and the canvas shows a single unreadable stack. Fix: apply the 200px
vertical stepping rule starting from the Trigger at (0,0).

**2. Left-to-right flow**
Increasing X values along the linear data path (x=0, x=200, x=400) produces a flow that reads
sideways. FloLess canvases are designed for top-to-bottom reading; horizontal flows contradict
the canonical direction. Fix: increase Y (not X) as the flow progresses downstream.

**3. Inconsistent spacing**
Mixing 50px, 300px, and 200px vertical gaps makes the layout look chaotic. Fix: use exactly 200px
vertical for linear flow and 300px horizontal between parallel branches.

**4. Display terminator in the middle**
Placing a Display node at y=200 with an Action at y=400 is structurally invalid — Display has
no output ports. Fix: always place Display at the bottommost Y of the branch.

**5. Condition branches at the same X**
Both true and false branches at x=0 overlap. Fix: offset the false branch 150px right of the
true branch (or spread them ±150px around the parent X).

**6. Missing port indexes in connection JSON**
Omitting `SourcePortIndex` or `TargetPortIndex` fields causes the connection to fail. Fix: always
include both port index fields, defaulting to 0 when there is only one port.

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
