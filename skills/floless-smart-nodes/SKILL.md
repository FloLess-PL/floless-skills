---
name: floless-smart-nodes
description: "Write FloLess Smart Nodes — compiled C# code for deterministic, zero-cost-per-execution workflow logic. Use when writing or fixing Smart Node code, running the compile-fix loop, choosing target frameworks (net8.0 vs net48 for Tekla), pinning software versions (tekla-2025), or iterating on compilation diagnostics. Covers the full diagnostic sequence — workflow nodes → node-context → compile → nodeUpdated."
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "0.9.18"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read Write
---

# floless-smart-nodes

Smart Nodes are compiled C# code blocks embedded in FloLess workflows. They execute deterministically, run at zero runtime token cost (no LLM call per execution), and are the preferred choice whenever logic is static or algorithmic. Every Smart Node is compiled once via Roslyn inside the desktop process and then runs on each workflow execution with full .NET performance.

When to load this skill: you are writing a new Smart Node, fixing compilation errors, choosing between net8.0 and net48 target frameworks, pinning a software version for Tekla API access, or iterating on `floless compile` diagnostics.

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

## When to use this skill

Use this skill when you need to:

- Write a new Smart Node action or trigger in C#
- Fix a C# compilation error after `floless compile --code file.cs --json`
- Choose between `--target-framework net8.0` (default) and `--target-framework net48` (Tekla)
- Pin a software version: `--software-version tekla-2025`
- Understand how the FloLess runtime calls your C# entry point
- Discover available skill packs (`floless skills --json`) or templates (`floless templates --type smart --json`)
- Iterate the compile-fix loop until `data.compiled` is `true`

## CRITICAL: how upstream data reaches a Smart Node (two mechanisms)

> **As of FloLess Phase 101.2 the legacy "Edit Input Fields" dialog is gone.** Smart Nodes
> no longer expose a per-field input editor, and you no longer "declare inputs" that must
> match upstream names. Upstream values reach your code through two mechanisms, both live in
> every node and both keyed off the **upstream node's own output-field names** — FloLess
> never renames a value across a connection.

### Mechanism 1 — inline `{{nodeId.fieldPath}}` tokens in the Instructions panel (primary)

Reference an upstream value directly in the Smart Node **Instructions** text using a
double-brace token: `{{nodeId.fieldPath}}`. At compile time a Roslyn rewriter
(`InlineVariablePostProcessor`) scans the AI-generated C# for that token **inside string
literals and interpolated strings** and replaces each occurrence with a **synthetic local
variable**, then prepends one defensive binding statement at the top of your entry method:

```csharp
// In Instructions you wrote:  …summarize {{excel_cell_changed_5555.cellValue}}…
// The rewriter injects this at the top of ExecuteAsync, then uses the local in place of the token:
var inline_excel_cell_changed_5555_cellvalue =
    inputs.TryGetValue("__inline_excel_cell_changed_5555_cellvalue__", out var __v_0) ? __v_0 : null;
```

Grammar (whitespace-tolerant; dotted paths allowed for nested fields): `{{ nodeId . fieldPath }}`
where `nodeId` matches `[A-Za-z0-9_-]+` and `fieldPath` matches `[A-Za-z0-9_.\-]+`. At runtime
FloLess resolves each token against the upstream node's emitted outputs and fills
`inputs["__inline_<slug>__"]`. If the upstream hasn't run yet the key is absent and the
synthetic local degrades to `null` — it never throws. This pipeline is always-on (the earlier
opt-in flag was retired in 101.2).

The Smart Node editor's **Context panel** (right side) lists exactly what you can reference:

- **Available inputs** — the upstream output keys wired into this node (these are the `nodeId.fieldPath` names).
- **Available APIs** — runtime API surfaces available to the node: `tekla`, `m365`, `google`, `trimbleconnect`.
- **Emitted inputs** — a JSON snapshot of the runtime-injected values the AI was told to expect (e.g. API tokens). Mirrors `EmittedInputsJson` on the node.

### Mechanism 2 — the raw `inputs` dictionary, keyed by upstream output-field names

Independently of any inline token, FloLess flattens every upstream node's outputs into the
`inputs` dictionary **directly under the upstream's own output-field names**. Read them with
`TryGetValue`:

```csharp
// Folder Watcher publishes: filePath, fileName, extension, folderPath, changeType, …
// (run `floless component folder-watcher --json` for the full output list)

// CORRECT — read by the upstream output-field name
inputs.TryGetValue("filePath", out var path);

// WRONG — there is no key "jFilePath" in inputs[]; this returns false silently
inputs.TryGetValue("jFilePath", out var path);
```

> **The single biggest mistake AI agents make on Smart Nodes — including in early v0.9 of this
> skill itself — is inventing custom input names that don't match the upstream component's
> output names.** This applies to BOTH mechanisms: an inline `{{node.field}}` whose field
> isn't a real upstream output resolves to `null`, and a `TryGetValue("invented")` returns
> false silently. There is no error in either case — the value is just absent.

Before writing any `{{node.field}}` token or `inputs.TryGetValue("…")` call, **discover the
actual output-field names of every upstream node**:

| Upstream node type | How to discover its output-field names |
|---|---|
| Trigger | `floless component <componentId> --json` → `outputs[].name` |
| Action | `floless component <componentId> --json` → `outputs[].name` |
| SmartNode | `floless workflow node-context --workflow current --node {id} --json` → `outputSchema` (the keys the upstream Smart Node returns from its `Dictionary<string, object>`) |
| ThinkNode | same as SmartNode — inspect via `node-context` |

Helper for the most common case (single Folder Watcher → SmartNode):

```bash
# List Folder Watcher output names — the keys you can read in inputs[] / reference as {{...}}
floless component folder-watcher --json | \
  python -c "import sys,json; print('\n'.join(o['name'] for o in json.load(sys.stdin)['data']['outputs']))"
# → filePath, fileName, fileNameWithoutExtension, extension, folderPath,
#   relativePath, changeType, oldFilePath, oldFileName, fileSize,
#   lastModified, createdAt, timestamp, files, fileCount
```

When you need a clearer name locally, **rename in your code** — don't try to remap the input:

```csharp
// Read by the upstream's name, then alias to whatever's clearer locally:
if (inputs.TryGetValue("filePath", out var raw) is false) return Error("...");
var jFilePath = raw.ToString();   // local alias, not an input key
```

### `SmartNodeInputSchema` / `SmartNodeOutputSchema` — still PascalCase, but role changed

The `.flo` JSON fields `SmartNodeInputSchema` and `SmartNodeOutputSchema` still exist, are
still serialized as a **JSON-encoded string** of `List<InputFieldSchema>`, and are still
deserialized **case-sensitively** with **PascalCase property names** (`Name`, `Label`, `Type`,
`Required`, `Description`, `DefaultValue`, `Options`, `Value`) — NOT lowercase. `floless
workflow update-smart-node` still accepts both. The casing rule is unchanged:

```json
// CORRECT — PascalCase, matches InputFieldSchema in the FloLess source
"SmartNodeOutputSchema": "[{\"Name\":\"result\",\"Label\":\"Result\",\"Type\":\"string\",\"Required\":true,\"Description\":\"…\"}]"

// WRONG — lowercase: deserializes to InputFieldSchema with Name=\"\", Type=\"string\" defaults
"SmartNodeOutputSchema": "[{\"name\":\"result\",\"type\":\"string\",\"required\":true}]"
```

Supported `Type` values: `"string"`, `"number"`, `"boolean"`, `"dropdown"`, `"FloImage"`. For
dropdowns, also populate `Options: [...]`.

What changed is the **role of `SmartNodeInputSchema`**: with the input dialog gone, it is no
longer the wiring mechanism. At runtime it only fills `inputs` keys that upstream did **not**
already populate — a **defaults-only fallback**. To pass a default that itself references an
upstream value, set the field's `DefaultValue` to a `{{upstream.port}}` template. Prefer
Mechanism 1 or 2 above for normal data flow. `SmartNodeOutputSchema` remains meaningful: it
declares what this node emits, which feeds downstream nodes' inline-variable autocomplete.

## How `EnsureRequiredUsings` auto-injects Tekla namespaces (for context, not avoidance)

When a Smart Node compiles, FloLess runs `SmartNodeCodeGenerator.EnsureRequiredUsings()`.
That function scans the **executable code** (comments and string-literal contents are
excluded — Roslyn-tokenized) for ~50 Tekla API type names like `new Model(`, `ModelObject`,
`Operation.RunMacro`, `Beam `, `Connection `, `Welds`. When it finds one, it auto-injects
the matching `using Tekla.*;` directive so AI-generated code that omitted the using still
compiles.

**You don't need to do anything to take advantage of this** — just write Tekla code
naturally; the using gets added for you. Document it here so the auto-injection isn't
mysterious when it shows up in the diff after a compile.

### One legitimate consequence

If your Smart Node sets `SmartNodeTargetFramework: "NetCore"` (in-process, no Tekla refs)
but you do reference Tekla types in real code, the injected `using Tekla.*;` will fail
because Tekla assemblies aren't loaded for NetCore. That's the auto-injection working
correctly — it's telling you the framework is wrong. Switch to `"NetFramework48"` +
`SmartNodeSoftwareVersion: "tekla-2025"` for any node that touches Tekla types.

### Comments and strings are safe

Comments like `// walks the Tekla Connection dialog and clicks Welds` and string literals
like `buttonText = "Welds"` do **NOT** trigger the auto-injection — only references in
executable code do. Write comments and user-facing strings in natural English without
worrying about coincidental substring matches.

(Earlier versions of FloLess substring-scanned the raw text including comments and
strings, which caused spurious `'Tekla' could not be found` errors on NetCore nodes whose
comments mentioned trigger words. That's been fixed in floless-app — the scan now uses a
syntax tree, which excludes trivia and literal contents by definition.)

## CRITICAL: every Smart Node needs a plain-English `SmartNodeExplanation`

The `.flo` JSON field `SmartNodeExplanation` populates the **"Explanation & Notes"** panel
shown in the Smart Node editor (left side, below the Instructions box). Workflow reviewers
read it to understand what a node does without opening the C# source. **Leave it blank and
your workflow is unusable for anyone but the author.**

This field is NOT generated automatically — neither by the AI code-generation pipeline nor
by `floless workflow create`. Static JSON authoring (Flow A) and AI-assisted authoring both
ship with `SmartNodeExplanation: ""` unless you write it yourself. The Title/Subtitle/Description
fields documented in `floless-canvas` are catalog/config metadata; this is the only field that
explains *what the code does in plain language*.

To set this and the rest of a Smart Node's persistent fields (`SmartNodeTargetFramework`,
`SmartNodeSoftwareVersion`, `SmartNodeInputSchema`, `SmartNodeOutputSchema`,
`SmartNodeInstructions`, `Title`/`Subtitle`/`Description`) on a node already in a loaded
workflow, use the `floless workflow update-smart-node` CLI command — it PATCHes the live
ViewModel atomically over HTTP, so you don't need to edit the `.flo` file by hand and reload.
See the `floless-cli` skill, "floless workflow update-smart-node" section in
`references/command-reference.md` for the option list.

### Required content shape

Three short paragraphs, plain English, no jargon:

1. **What question this node answers** — the user-facing purpose (e.g. "Answers: 'I clicked at
   (x,y) on a connection dialog screenshot — what variable is that?'").
2. **Inputs and outputs** — what flows in, what flows out, in concrete terms.
3. **Mechanism in one sentence** — how the code does it, at a level a non-coder grasps.

### Example

```json
// CORRECT — populated SmartNodeExplanation
{
  "Description": "Lookup Field At Point",
  "SmartNodeExplanation": "Answers the question: 'I clicked at (x, y) on a connection dialog screenshot — what variable is that?'\n\nInputs: the connection id (e.g. 146) and the click coordinate (x, y) in the dialog's own coordinate space — same coordinates that coordinates.json uses, so they line up cleanly with screenshots.\n\nOutput: the attribute name (e.g. 'tj1'), its full namespaced form (joint_attributes.tj1), the original .j-file value, and the visible text it matched. If the click didn't land in any field's rectangle, returns found=false."
}

// WRONG — blank Explanation: editor panel shows nothing, reviewers have to read the C# source
{
  "Description": "Lookup Field At Point",
  "SmartNodeExplanation": ""
}
```

### Make it part of the compile-fix loop

After every successful compile (`data.compiled: true`), confirm `SmartNodeExplanation` is
populated and meaningful before embedding the source in the `.flo`. A node is not "done" just
because the C# compiles — silent rule that costs nothing to follow:

```
1. Write/edit C# code
2. floless compile --code <file> --json   → check data.compiled is true
3. Write SmartNodeExplanation (3 paragraphs, plain English)
4. Embed source + explanation + framework metadata in .flo
```

## Smart Node vs Think Node — when to choose

| Criterion | Smart Node (C#) | Think Node (LLM) |
|---|---|---|
| Logic type | Deterministic, algorithmic | Reasoning, language, judgment |
| Runtime cost | Zero per execution (compiled once) | One LLM API call per execution |
| Output stability | Identical inputs → identical outputs | Non-deterministic |
| Setup | Must compile; one-time Roslyn cost | No compilation step |
| Good for | Math, transforms, Tekla API, file I/O, HTTP | Classification, extraction, summarization |

**Rule of thumb:** if you can write a unit test that fully specifies the output given the input, use a Smart Node. If the correct output depends on language understanding or judgment, use a Think Node.

For Think Node authoring, see the `floless-think-nodes` skill.

---

## WARNING: `success: true` does NOT mean compilation succeeded

> **This is the #1 mistake agents make with the compile API.**

When you call `floless compile --code file.cs --json`, the `success` field in the envelope is **API-level**, not domain-level. `success: true` means the HTTP call to the desktop reached its handler — it says nothing about whether your C# code compiled.

**Always check `data.compiled` (boolean).**

### SUCCESS case — API succeeded AND code compiled

```json
{
  "success": true,
  "data": {
    "compiled": true,
    "diagnostics": [],
    "nodeUpdated": false,
    "targetFramework": "net8.0"
  }
}
```

### FAILURE case — API succeeded BUT code did NOT compile

```json
{
  "success": true,
  "data": {
    "compiled": false,
    "diagnostics": [
      {
        "severity": "Error",
        "id": "CS0103",
        "message": "The name 'foo' does not exist in the current context",
        "line": 12,
        "column": 8
      }
    ]
  }
}
```

The exit code from `floless compile` (when using `--json`) is:
- `0` when `data.compiled` is `true`
- `1` when `data.compiled` is `false` OR when the API call itself failed

Always parse the envelope; never rely on `success` alone.

---

## Compile-fix loop

This is the standard 5-step procedure for authoring a Smart Node. **A node is NOT
done at step 3** — leaving the explanation blank ships an unusable node, see the
"plain-English `SmartNodeExplanation`" section above.

**Step 1:** Write (or edit) your C# source file. Name it anything — e.g., `node.cs`.

**Step 2:** Compile it:

```bash
floless compile --code node.cs --json
```

**Step 3:** Parse the response. Check `data.compiled`:

- If `data.compiled` is `true` → continue to Step 5.
- If `data.compiled` is `false` → go to Step 4.

**Step 4:** Read every entry in `data.diagnostics[]`. Each diagnostic has:

- `severity` — `"Error"` or `"Warning"`
- `id` — Roslyn code (e.g., `CS0103`)
- `message` — human-readable explanation
- `line` and `column` — position in your source file

Fix the errors in your source file. Repeat from Step 2.

**Important:** Only `severity: "Error"` entries block compilation. `severity: "Warning"` entries do not block compilation — the node is still deployed. However, fix warnings before shipping.

**Step 5 — Write the plain-English `SmartNodeExplanation`:**

Once the code compiles clean, write the 3-paragraph explanation that populates the editor's
"Explanation & Notes" panel. See the dedicated section above for required content shape.
Skipping this step ships a node that compiles but is undocumented — workflow reviewers
have no idea what it does without reading the C#.

```text
Paragraph 1: What question this node answers (user-facing purpose)
Paragraph 2: Inputs and outputs in concrete terms
Paragraph 3: Mechanism in one sentence
```

Embed `SmartNodeExplanation` into the `.flo` JSON alongside `SmartNodeGeneratedCode`,
`SmartNodeTargetFramework`, and `SmartNodeSoftwareVersion` — all four belong together in
every Smart Node entry.

---

## Full diagnostic sequence

Use this sequence when you need to fix an existing Smart Node that is already part of a loaded workflow:

**Step 1 — List nodes in the loaded workflow:**

```bash
floless workflow nodes --workflow current --json
```

Find the Smart Node by looking for `"hasCode": true` in the response. Note its `id` (a GUID).

**Step 2 — Fetch the node's full context:**

```bash
floless workflow node-context --workflow current --node {nodeId} --json
```

The response `data` object contains:
- `generatedCode` — the current C# source
- `instructions` — the natural-language instructions the node was built from
- `inputSchema` — port definitions for inputs
- `outputSchema` — port definitions for outputs
- `upstream` — nodes feeding into this node
- `downstream` — nodes this node feeds into

**Step 3:** Read `data.generatedCode`. Copy it to a local file (e.g., `fix.cs`). Identify and fix the issue.

**Step 4 — Compile the fix back into the workflow:**

```bash
floless compile --code fix.cs --workflow current --node {nodeId} --json
```

When `--workflow` and `--node` are both provided, the response includes `"nodeUpdated": true` on success, meaning the loaded workflow in the desktop has been updated in-place. No manual reload is needed.

> **CRITICAL — after editing a `.flo` on disk while FloLess has it loaded, the editor's
> "Error" badge and `data.diagnostics[]` cache do NOT auto-refresh.** The stored
> compile state in the loaded workflow is the result of FloLess's *last* compile of
> *that node's source as it was when the .flo was first loaded*. Saving new source
> bytes to the file via Python/text-edit does not invalidate the cache — the editor
> keeps showing the stale Error badge until either (a) the user clicks **Recompile**
> in the Smart Node editor, (b) the user closes the file and re-opens it, or (c)
> a fresh `floless compile --workflow current --node {nodeId}` runs against the loaded
> node.
>
> **Always run option (c) for every Smart Node after editing the `.flo` on disk:**
>
> ```bash
> for nid in $(floless workflow nodes --workflow current --json | jq -r '.data[] | select(.hasCode) | .id'); do
>   floless compile --code "<path-to-its-source>.cs" --workflow current --node "$nid" --json | jq '.data | {compiled, nodeUpdated}'
> done
> ```
>
> A standalone `floless compile --code <file>` is necessary but NOT sufficient —
> it confirms the source compiles, but does NOT push the result into the loaded
> workflow's compile-state cache. The Error badge stays. Run the workflow-bound
> form (`--workflow current --node {id}`) to actually clear it.

> **CRITICAL — the reverse trap: if the Smart Node editor is OPEN, do NOT push code to it
> via the CLI.** The editor snapshots `node.GeneratedCode` into its own buffer **once, at
> open time**, and never observes external writes after that. A workflow-bound
> `floless compile --code … --workflow current --node {id}` *does* overwrite
> `node.GeneratedCode` and set the node's state to `Ready` — but the open editor doesn't
> see it. Worse, the node's `GenerationState` only flips to `Stale` when its **Instructions**
> change; an external **code** write never marks it Stale, so the editor still reads
> `Ready` and gives no hint of divergence. If the user then clicks **Recompile** it
> recompiles the editor's *stale* buffer, and **Save clobbers your CLI-pushed code**.
>
> **Guidance:** close the Smart Node editor before any CLI compile/push for that node.
> After pushing, do NOT trust `nodeUpdated: true`, the `generationState`, or the
> "Node updated" toast — they can all read green over stale state. Verify the push
> actually landed by diffing your source against what the node holds:
>
> ```bash
> floless workflow node-context --workflow current --node {id} --json | jq -r '.data.generatedCode'
> ```
>
> (Note: `floless workflow update-smart-node` cannot set the code body — it PATCHes
> metadata/schema/instructions only. `floless compile … --workflow current --node {id}`
> is the only CLI path that writes `GeneratedCode`.)

---

## Target framework selection

The `--target-framework` option controls which .NET runtime the compiled assembly targets.

### CLI value vs `.flo` stored value (don't confuse these)

These are two separate vocabularies for the same concept:

| Layer | .NET Core / in-process | .NET Framework 4.8 / Tekla |
|---|---|---|
| `floless compile --target-framework` CLI flag | `net8.0` (default) | `net48` |
| `.flo` JSON `SmartNodeTargetFramework` field | `"NetCore"` | `"NetFramework48"` |
| FloLess editor dropdown DisplayName | `.NET (in-process)` | `.NET Framework (Tekla)` |
| Schema/JSON-schema description text | `.NET Core` | `.NET Framework 4.8` |

The schema description and the dropdown DisplayName are human-readable; **the stored
enum in `.flo` JSON is `NetCore` or `NetFramework48`** — no dot, no space. Writing
`".NET Framework 4.8"` (the description string) into `SmartNodeTargetFramework`
deserializes silently to the default `NetCore`, and the editor opens the node with
the wrong framework selected, which produces compile errors like
`'Tekla' could not be found` even though the node was authored as Tekla.

Same rule for `SmartNodeSoftwareVersion`: write `"tekla-2025"` (when paired with
`NetFramework48`) or `"none"` / empty string (when paired with `NetCore`).

```json
// CORRECT — Tekla Smart Node
{
  "SmartNodeTargetFramework": "NetFramework48",
  "SmartNodeSoftwareVersion":  "tekla-2025"
}

// CORRECT — non-Tekla Smart Node
{
  "SmartNodeTargetFramework": "NetCore",
  "SmartNodeSoftwareVersion":  "none"
}

// WRONG — schema description strings; deserialize to NetCore default
{
  "SmartNodeTargetFramework": ".NET Framework 4.8",
  "SmartNodeSoftwareVersion":  "tekla-2025"
}
```



### `net8.0` (default)

- Used for standalone Smart Nodes with no Tekla dependency
- Default when `--target-framework` is omitted
- Runs in the FloLess desktop process (.NET 8)
- Available assemblies: System.*, System.Text.Json, System.Net.Http (when enabled in settings), and more

```bash
floless compile --code node.cs --json
# same as:
floless compile --code node.cs --target-framework net8.0 --json
```

### `net48` (for Tekla)

- Required when your code references Tekla OpenAPI types (e.g., `Tekla.Structures.Model`)
- Tekla OpenAPI is a .NET Framework 4.8 library; it cannot be referenced from net8.0
- Must be paired with `--software-version tekla-2025`

```bash
floless compile --code tekla-node.cs --target-framework net48 --software-version tekla-2025 --json
```

**Mismatch error:** If you use `--software-version tekla-2025` without `--target-framework net48`, the compile response will contain `errorCode: "software_version_mismatch"` and the node will not compile. Always pair Tekla software versions with `net48`.

### What's actually referenceable at runtime (compile ⊋ run)

> **`data.compiled: true` does NOT guarantee a `net48`/Tekla node will run.** `floless
> compile` runs Roslyn inside the FloLess **desktop** process, which has a rich reference
> set. A `net48`/Tekla Smart Node, however, executes in the separate **TeklaBridge**
> process, whose reference set is a strict subset. Code that satisfies the compiler can
> still fail at run with `CS0234`/`TypeLoadException` for a type the bridge never loads.

A `net48`/Tekla Smart Node's runtime references are **only**:

- **BCL**: `mscorlib`, `System`, `System.Core`, `System.Runtime`, `System.Collections`,
  `System.Linq`, `System.Threading.Tasks`, `netstandard`, `System.Text.Json`,
  `System.Memory`, `System.Buffers`, `System.Net.Http`, `System.ObjectModel`,
  `System.ComponentModel`.
- **Tekla**: the `Tekla.*` DLLs for the pinned `--software-version`.
- **The three FloLess scripting stubs** compiled into the bridge: `IScriptAction`
  (`FloLess.Core.Scripting.Interfaces`), `ScriptContext` (`FloLess.Core.Scripting`), and
  `FloImage` (`FloLess.Core.Models`).
- Any extra assembly names you enabled in Settings → Smart Node → Assemblies.

**Nothing else from `FloLess.Core.*` is available at run** — there is no `FloLess.Core.dll`
in the bridge. So `FloLess.Core.Extensions`, helpers, models other than `FloImage`, etc. all
throw `CS0234` at run even when compile passed (see the BCL-only convention under "Coding
conventions"). The
in-process `net8.0` path is more forgiving, but **do not rely on the compile step to vet a
Tekla node** — always finish with an actual run:

```bash
floless workflow run --workflow current --json   # confirm the node executes, not just compiles
```

This is the deeper layer beneath the `success != compiled` warning above: `compiled != runs`
for the Tekla bridge.

---

## Software version pinning

Software version pinning adds platform-specific API assemblies to the compilation context.

| Flag value | Effect |
|---|---|
| `--software-version tekla-2025` | Adds Tekla Structures 2025 DLLs to compilation references |
| `--software-version none` | No extra assemblies; standalone code only (default) |

The configured version must match the Tekla Structures version installed on the machine running FloLess. A version mismatch returns:

```json
{
  "success": false,
  "error": "Software version mismatch",
  "errorCode": "software_version_mismatch"
}
```

If you get this error, check which Tekla version is running (visible in FloLess Settings → Integrations) and adjust `--software-version` accordingly.

---

## Skills and templates discovery

FloLess ships skill packs and templates to help you start Smart Nodes faster.

**List all available Smart Node skill packs:**

```bash
floless skills --json
```

**Filter by group:**

```bash
floless skills --json --group tekla
```

Each skill pack in the response has an `id`, `name`, `description`, and list of included templates.

**List Smart Node boilerplate templates:**

```bash
floless templates --type smart --json
```

Each template has a `templateId`, `name`, `description`, and `code` field (the boilerplate C# source). Copy the `code` to a local file, customize it, then compile.

**List Think Node templates (for comparison):**

```bash
floless templates --type think --json
```

---

## Coding conventions

Every C# Smart Node sample in this skill follows the root `CLAUDE.md` coding standards. Your Smart Node code must also follow these conventions:

- **No `namespace` declaration** — FloLess compiles Smart Node source in Roslyn **script mode**, which forbids namespace declarations. Writing `namespace FloLessNodes;` (or any other namespace wrapper) produces `Cannot declare namespace in script code`. Put `using` directives first, then the entry-point class at the top level — no namespace.
- **Latest C# syntax** — `LangVersion` is set to "latest" in the Roslyn compilation context. Use records, pattern matching, and other modern constructs freely. (File-scoped namespaces are off-limits because `namespace` itself is — see rule above.)
- **`is false` instead of `!`** — write `if (result is false)` not `if (!result)`.
- **No underscore-prefixed field names** — write `private int count;` (no leading underscore on field names).
- **One empty line between properties** for readability.
- **`ConfigureAwait(false)` on every `await`** — Smart Nodes run in a service context where there is no meaningful SynchronizationContext, but the convention prevents accidental context capture and satisfies the root project rule.
- **Use BCL null/empty checks — NOT `FloLess.Core.Extensions.IsNullOrEmpty()`.** Write
  `string.IsNullOrEmpty(s)` and `list.Count == 0` (or `dict.Count == 0`). The root
  `CLAUDE.md` "prefer `IsNullOrEmpty()` extension" rule is for app projects that reference
  `FloLess.Core.dll` — Smart Node source does **not**. In particular the net48/Tekla bridge
  runtime never loads `FloLess.Core.dll`, so `FloLess.Core.Extensions.IsNullOrEmpty()` throws
  **CS0234 at run** even though `floless compile` (which has a richer reference set) accepts
  it. See "What's actually referenceable at runtime (compile ⊋ run)" above.
- **No `Task.Run()` hacks** — if your code deadlocks without `Task.Run()`, the root cause is sync-over-async. Fix the root cause.
- **No silently-swallowed `catch` blocks** — always propagate or log exceptions.
- **No `Environment.Exit()`** — the Smart Node runs inside the FloLess desktop process; calling `Exit()` kills the entire application.

See [`references/code-patterns.md`](references/code-patterns.md) for full annotated examples.

---

## Common compile errors and fixes

| Error code | Likely cause | Fix |
|---|---|---|
| `CS0103` | Name does not exist — missing `using`, typo, or out-of-scope variable | Add the missing `using` directive or check variable scope |
| `CS0246` | Type not found — missing assembly reference or namespace | Confirm the type is in an allowed assembly; add correct `using` |
| `CS0117` | Type has no member — called a method that doesn't exist on that type | Check the type's actual API; correct the method name |
| `CS1061` | Object does not contain definition — wrong member or missing extension | Verify the type; add missing `using` for extension methods |
| `CS0234` | Namespace member not found — wrong sub-namespace | Correct the namespace path |
| `CS0161` | Not all code paths return a value | Add a `return` statement for every branch |
| `CS0029` | Cannot implicitly convert type | Add explicit cast or use correct type |

For each error in `data.diagnostics[]`, find the line/column, open your source file at that location, read the message carefully, apply the fix above, then re-run compile.

---

## Progressive disclosure

Full annotated C# examples (entry point contract, echo node, async HTTP call, JSON transform, collection aggregation, Tekla node stub, and worked compile-fix-loop iteration) are in:

- [`references/code-patterns.md`](references/code-patterns.md)

---

## Cross-skill links

| Skill | When to use it alongside this skill |
|---|---|
| `floless-cli` | Envelope parsing, compile command reference, port file discovery, all CLI options |
| `floless-workflows` | Flow B context — using `floless workflow add-node` / `connect` after a Smart Node compiles |
| `floless-think-nodes` | When your logic requires LLM reasoning instead of deterministic C# |
| `floless-triggers` | When writing a Smart Node that acts as a trigger (implements `IScriptTrigger`) |
