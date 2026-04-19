# Layout guide — floless-canvas reference

Deep-dive reference for canvas positioning in FloLess workflows. Load this file when the SKILL.md
summary is insufficient — for example, when working with extended node types, producing complex
fan-out or fan-in topologies, or needing the exact CLI flags for setting node positions.

---

## Coordinate system basics

| Property         | Value                                              |
|------------------|----------------------------------------------------|
| Origin           | (0, 0) — top-left corner of the canvas             |
| Primary flow axis| Y — increases downward (downstream = higher Y)     |
| Branch axis      | X — increases rightward (used for parallel branches)|
| Units            | Device-independent pixels (DIPs)                  |
| Default zoom     | 1.0 (no scaling; stored coordinates are absolute)  |
| Viewport offset  | Cosmetic only; does not affect stored X/Y values   |

Coordinates are stored directly in the workflow JSON as floating-point numbers. Zoom and pan
settings are session-state only and reset when the workflow is closed and reopened. Always design
layouts using absolute coordinate values, never viewport-relative positions.

---

## Port index by node type

Zero-based port indexes. Connections use `SourcePortIndex` and `TargetPortIndex` fields.

### Primary node types (authoritative — verified against NodeTypeRegistry.cs)

| Node type  | Input ports | Output ports | Input semantics            | Output semantics                                              |
|------------|-------------|--------------|----------------------------|---------------------------------------------------------------|
| Trigger    | 0           | 1            | (none)                     | 0 = trigger event payload (e.g., cell value, model event)    |
| Action     | 1           | N (1+)       | 0 = upstream data          | 0 = action result; 1+ = secondary outputs (provider-specific)|
| SmartNode  | 1           | 1            | 0 = JSON input             | 0 = JSON output                                               |
| ThinkNode  | 1           | 1            | 0 = LLM input context      | 0 = LLM output text                                           |
| Condition  | 1           | 2            | 0 = value to test          | 0 = true branch; 1 = false branch                             |
| Display    | 1           | 0            | 0 = value to show          | (none — terminal)                                             |

### Extended node types

For extended types below, port counts are based on NodeTypeRegistry.cs documentation. If a type
is missing from this table, query `floless schema --type workflow --json` for the authoritative
per-node port counts at runtime.

| Node type      | Input ports | Output ports | Notes                                                        |
|----------------|-------------|--------------|--------------------------------------------------------------|
| Input          | 0           | 1            | Manual data entry node; output 0 = entered value             |
| Iterator       | 1           | 2            | 0 = collection; out: 0 = current item, 1 = index             |
| Aggregator     | N (1+)      | 1            | Collects multiple upstream outputs; out: 0 = aggregated data |
| DataProcessing | 1           | 1            | Transform node; in: 0 = data; out: 0 = transformed data      |
| Cluster        | 1           | 1            | Grouping container; in/out semantics match inner boundary     |
| Note           | 0           | 0            | Annotation only; no data ports                               |
| Group          | 0           | 0            | Visual grouping rectangle; no data ports                     |
| Connector      | 1           | 1            | Wire routing aid; in: 0 = passthrough; out: 0 = passthrough  |

If your NodeType is missing from this table, query `floless schema --type workflow` for the
authoritative per-node port counts.

---

## Canonical layout patterns

### Pattern 1: Linear flow

Trigger → Action → Display as a vertical column.

```json
{
  "Nodes": [
    { "Id": "a1b2c3d4-0000-0000-0000-000000000001", "Type": "Trigger",  "X": 0, "Y": 0   },
    { "Id": "a1b2c3d4-0000-0000-0000-000000000002", "Type": "Action",   "X": 0, "Y": 200 },
    { "Id": "a1b2c3d4-0000-0000-0000-000000000003", "Type": "Display",  "X": 0, "Y": 400 }
  ],
  "Connections": [
    { "SourceNodeId": "a1b2c3d4-0000-0000-0000-000000000001", "SourcePortIndex": 0,
      "TargetNodeId": "a1b2c3d4-0000-0000-0000-000000000002", "TargetPortIndex": 0 },
    { "SourceNodeId": "a1b2c3d4-0000-0000-0000-000000000002", "SourcePortIndex": 0,
      "TargetNodeId": "a1b2c3d4-0000-0000-0000-000000000003", "TargetPortIndex": 0 }
  ]
}
```

Node coordinates: (0,0) → (0,200) → (0,400). Vertical spacing: 200px.

### Pattern 2: Branching flow (Condition)

Trigger → Condition → Action-true + Action-false → Display-true + Display-false.

| Node         | Type      | x    | y   |
|--------------|-----------|------|-----|
| Trigger      | Trigger   | 0    | 0   |
| Condition    | Condition | 0    | 200 |
| Action-true  | Action    | -150 | 400 |
| Action-false | Action    | 150  | 400 |
| Display-true | Display   | -150 | 600 |
| Display-false| Display   | 150  | 600 |

Connections:
- Trigger(out:0) → Condition(in:0)
- Condition(out:0) → Action-true(in:0)   ← true branch uses port 0
- Condition(out:1) → Action-false(in:0)  ← false branch uses port 1
- Action-true(out:0) → Display-true(in:0)
- Action-false(out:0) → Display-false(in:0)

Branch horizontal offset: ±150px around the parent X. The Condition node sits at the branch origin
(x=0, y=200); true branch shifts left (x=-150), false branch shifts right (x=150). Both Display
terminators stay at the bottommost Y (600) in their respective branch columns.

### Pattern 3: Parallel fan-out

Trigger → Action-A + Action-B + Action-C (three parallel branches).

| Node     | Type    | x    | y   |
|----------|---------|------|-----|
| Trigger  | Trigger | 0    | 0   |
| Action-A | Action  | -300 | 200 |
| Action-B | Action  | 0    | 200 |
| Action-C | Action  | 300  | 200 |

The Trigger connects its single output port (0) to each Action's input port (0). One source
port can fan out to multiple targets — FloLess allows multiple connections from a single
output port.

Connections:
- Trigger(out:0) → Action-A(in:0)
- Trigger(out:0) → Action-B(in:0)
- Trigger(out:0) → Action-C(in:0)

Horizontal stride: 300px between parallel actions (x=-300, x=0, x=300), centered on the Trigger's X.

### Pattern 4: Aggregator convergence (fan-in)

Action-A + Action-B + Action-C → Aggregator → Display.

| Node        | Type        | x    | y   |
|-------------|-------------|------|-----|
| Action-A    | Action      | -300 | 0   |
| Action-B    | Action      | 0    | 0   |
| Action-C    | Action      | 300  | 0   |
| Aggregator  | Aggregator  | 0    | 200 |
| Display     | Display     | 0    | 400 |

Place the Aggregator at the horizontal midpoint of its inputs (x=0 for three inputs at
x=-300, x=0, x=300). Connections from each Action output(0) to Aggregator input ports.

Connections:
- Action-A(out:0) → Aggregator(in:0)
- Action-B(out:0) → Aggregator(in:1)
- Action-C(out:0) → Aggregator(in:2)
- Aggregator(out:0) → Display(in:0)

---

## Common layout mistakes and fixes

**(a) All nodes at (0,0)**
Every node occupies the same position. The canvas shows a single stacked rectangle. Fix: apply
200px vertical stepping from the Trigger origin.

**(b) Left-to-right flow**
X values increase along the linear data flow direction, producing a sideways layout. FloLess
canvases are designed to read top-to-bottom; horizontal flows contradict the canonical direction
and make reviews harder. Fix: always increase Y (not X) as the flow progresses downstream.

**(c) Inconsistent spacing**
Mixing 50px, 150px, and 400px gaps produces a chaotic layout. Fix: use exactly 200px vertical
between sequential nodes and 300px horizontal between parallel branches throughout the workflow.

**(d) Display terminator in the middle of a flow**
Placing a Display node at y=200 with an Action at y=400 is structurally impossible — Display
has no output ports. Fix: always place Display at the bottommost Y of its branch.

**(e) Orphaned nodes with no connections**
Nodes that have no connections float at their position and produce visual clutter. Fix: either
connect the node or delete it with `floless workflow delete-node`.

**(f) Missing port indexes in connection JSON**
Omitting `SourcePortIndex` or `TargetPortIndex` fields in the connection object causes a
validation error. Fix: always include both fields. Default to 0 when there is only one port.

---

## Using `floless workflow add-node --x N --y N`

To set node positions when building via Flow B (augmenting the loaded current workflow):

```bash
floless workflow add-node --workflow current --type Trigger --component-id {triggerId} --x 0 --y 0 --json
floless workflow add-node --workflow current --type Action --component-id {actionId} --x 0 --y 200 --json
floless workflow add-node --workflow current --type Display --x 0 --y 400 --json
```

The `--x` and `--y` options accept floating-point values. If omitted, the desktop places the node
at the viewport center (whatever the current pan/zoom shows) — avoid relying on this default,
as the result is non-deterministic across sessions.

After adding nodes, wire connections with:

```bash
floless workflow connect --workflow current \
  --source-node {sourceGuid} --source-port 0 \
  --target-node {targetGuid} --target-port 0 --json
```

Discover node GUIDs from the `add-node` response (`data.id`) or from:

```bash
floless workflow nodes --workflow current --json
```

For the full mutation flow (create, add, connect, validate, export), see:
[floless-workflows skill](../../floless-workflows/SKILL.md)

---

## References

- `src/FloLess.CLI/Commands/WorkflowCommand.cs:533` — `add-node` command definition with
  `--x` and `--y` option declarations.
- `src/FloLess/Core/Services/SmartNode/NodeTypeRegistry.cs` — Authoritative source for
  port counts per node type. When in doubt, this file takes precedence over this guide.
