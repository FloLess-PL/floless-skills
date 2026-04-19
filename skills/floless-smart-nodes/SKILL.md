---
name: floless-smart-nodes
description: "Write FloLess Smart Nodes — compiled C# code for deterministic, zero-cost-per-execution workflow logic. Use when writing or fixing Smart Node code, running the compile-fix loop, choosing target frameworks (net8.0 vs net48 for Tekla), pinning software versions (tekla-2025), or iterating on compilation diagnostics. Covers the full diagnostic sequence — workflow nodes → node-context → compile → nodeUpdated."
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
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

This is the standard 4-step procedure for authoring a Smart Node:

**Step 1:** Write (or edit) your C# source file. Name it anything — e.g., `node.cs`.

**Step 2:** Compile it:

```bash
floless compile --code node.cs --json
```

**Step 3:** Parse the response. Check `data.compiled`:

- If `data.compiled` is `true` → done. The code is valid.
- If `data.compiled` is `false` → go to Step 4.

**Step 4:** Read every entry in `data.diagnostics[]`. Each diagnostic has:

- `severity` — `"Error"` or `"Warning"`
- `id` — Roslyn code (e.g., `CS0103`)
- `message` — human-readable explanation
- `line` and `column` — position in your source file

Fix the errors in your source file. Repeat from Step 2.

**Important:** Only `severity: "Error"` entries block compilation. `severity: "Warning"` entries do not block compilation — the node is still deployed. However, fix warnings before shipping.

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

---

## Target framework selection

The `--target-framework` option controls which .NET runtime the compiled assembly targets.

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

- **Latest C# syntax** — `LangVersion` is set to "latest" in the Roslyn compilation context. Use records, pattern matching, file-scoped namespaces, and other modern constructs freely.
- **`is false` instead of `!`** — write `if (result is false)` not `if (!result)`.
- **No underscore-prefixed field names** — write `private int count;` (no leading underscore on field names).
- **One empty line between properties** for readability.
- **`ConfigureAwait(false)` on every `await`** — Smart Nodes run in a service context where there is no meaningful SynchronizationContext, but the convention prevents accidental context capture and satisfies the root project rule.
- **`dictionary.IsNullOrEmpty()` extension** — use `FloLess.Core.Extensions.IsNullOrEmpty()` instead of `!= null && Count > 0` checks.
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
