---
name: floless-cli
description: Connect to and drive the FloLess CLI from any AI terminal. Use when connecting to the FloLess desktop app, parsing the response envelope, handling CLI errors, recovering from port-file failures, or understanding exit codes. Covers port-file discovery at %LocalAppData%/FloLess/cli-api.port, the Stripe-style envelope shape, desktop lifecycle (floless start / floless close), and the full reference for all 27 shipping commands. Windows only.
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read Write
---

# floless-cli

The `floless-cli` skill teaches AI agents how to connect to, communicate with, and recover from
failures in the FloLess desktop CLI. It is the **trust spine** for all CLI interactions: every
other FloLess skill cross-links here for the connection pattern, envelope shape, and error
handling. Load this skill first when starting any session that involves driving the FloLess
desktop via `floless` commands.

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see `references/command-reference.md` in this skill.

## When to use this skill

- **Connecting to FloLess desktop** — you need to issue any `floless` command against a live
  FloLess instance and want the connection pattern + port file details.
- **Parsing CLI responses** — you received a JSON envelope and need to know which fields to read
  (`errorCode` vs `error` vs `errorWrapper.message`).
- **Handling CLI errors** — exit code 1, `success: false`, or no port file found.
- **Recovering from port-file failures** — the port file is missing, corrupt, or the PID is dead.
- **Understanding the 27 shipping commands** — you need the exact option names for any command.

## Prerequisites

- FloLess desktop app installed on Windows.
- `floless` CLI on PATH. Verify with:

```bash
floless --version
```

- Desktop app running before issuing any command that calls the API (exceptions: `floless start`,
  `floless --version`, and help flags work without the desktop).

## Port file discovery

The CLI does NOT use a fixed TCP port. On startup, the FloLess desktop writes a port file that
contains the dynamically assigned port, a per-session auth token, the desktop's PID, and the
desktop version. The CLI reads this file on every invocation to discover where to connect.

**Location:**

| Shell | Path |
|-------|------|
| PowerShell / CMD | `%LocalAppData%\FloLess\cli-api.port` |
| Git Bash | `${LOCALAPPDATA:-$HOME/AppData/Local}/FloLess/cli-api.port` |

**Port file format:**

```json
{
  "Port": 51432,
  "Token": "<redacted>",
  "Pid": 12340,
  "Version": "1.0.0"
}
```

Fields (PascalCase, case-insensitive deserialization):

| Field | Type | Purpose |
|-------|------|---------|
| `Port` | int | TCP port the desktop HTTP API is listening on |
| `Token` | string | Bearer token sent as `Authorization: Bearer {token}` header |
| `Pid` | int | Desktop process ID — used to detect stale port files |
| `Version` | string | Desktop app version string |

The CLI uses `ConnectionInfo.Discover()` (`src/FloLess.CLI/ApiClient/ConnectionInfo.cs`) to read
and validate this file on every command invocation.

## Three port-file failure modes

`ConnectionInfo.Discover()` returns `null` in three situations, each with a distinct recovery path:

**Mode 1 — File missing:** The port file does not exist at the expected path.
- **Cause:** FloLess desktop is not running.
- **Recovery:** `floless start` — launches the desktop and waits up to 30 seconds for the API
  to become responsive. Returns exit 0 when ready, exit 1 on timeout.

**Mode 2 — Invalid JSON:** The port file exists but cannot be parsed as JSON, or is missing
required fields (`Port`, `Token`).
- **Cause:** File corrupt — typically a partial write during a crash or unexpected shutdown.
- **Recovery:** Delete the file, then run `floless start` to launch fresh. The start command
  writes a new, valid port file when the desktop becomes ready.

**Mode 3 — Dead PID:** The port file exists and parses correctly, but `Process.GetProcessById(Pid)`
throws — the process is no longer alive.
- **Cause:** Desktop crashed or was killed without cleaning up the port file.
- **Recovery:** `floless start` — the start command performs the same idempotency check, detects
  the dead PID, launches a new desktop instance, and writes a fresh port file.

**Unified recovery pattern for all 3 modes:**

```bash
floless nodes --json
if [ $? -ne 0 ]; then
  floless start --json
  floless nodes --json
fi
```

## The --json discipline

**Always use `--json` from AI terminals.** Without it, most commands produce human-readable tables
that are difficult to parse reliably. The `--json` flag causes every command to output the raw
Stripe-style API envelope to stdout.

The single exception is `floless schema`, which always outputs JSON regardless of the `--json`
flag (it has no human-readable alternative).

```bash
# Correct — AI terminal usage
floless nodes --json
floless workflow list --json
floless compile --code MyNode.cs --json

# Avoid — human-readable output, not machine-parseable
floless nodes
floless workflow list
```

## Response envelope

All CLI commands (with `--json`) emit a consistent Stripe-style envelope.

**Success:**

```json
{
  "success": true,
  "data": { "...": "..." },
  "count": 42
}
```

- `success: true` — the API call itself succeeded.
- `data` — the result payload. Shape varies by command (see `references/command-reference.md`).
- `count` — present when `data` is an array; holds the total item count.

**Error:**

```json
{
  "success": false,
  "error": "Node 'abc-123' not found in workflow.",
  "errorCode": "not_found_node",
  "errorWrapper": {
    "code": "not_found_node",
    "message": "Node 'abc-123' not found in workflow.",
    "details": { "nodeId": "abc-123" }
  }
}
```

**Parsing rule:** Parse `errorCode` for machine-stable branching — it is a snake_case enum value
that will not change between versions. Use `errorWrapper.message` for display to humans.
The flat `error` string is preserved for backward compatibility only; avoid relying on its exact
wording in automation.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success — envelope `success: true` (or stdin/file read success for standalone operations) |
| `1` | Failure — any of: network error, non-2xx HTTP response, `success: false` envelope, JSON parse error, desktop unreachable (null `ConnectionInfo`) |

The CLI never returns any code other than 0 or 1.

## Size limits

| Route | Limit | Error code |
|-------|-------|------------|
| `floless compile` | 1 MB request body | `payload_too_large` |
| `floless workflow create` | 10 MB request body | `payload_too_large` |
| `floless workflow validate` | 10 MB request body | `payload_too_large` |

When the limit is exceeded, the envelope is:

```json
{
  "success": false,
  "errorCode": "payload_too_large",
  "errorWrapper": {
    "code": "payload_too_large",
    "message": "Request body exceeds the 1 MB limit.",
    "details": { "limitBytes": 1048576 }
  }
}
```

## Common error codes

| `errorCode` | Meaning | Recovery |
|-------------|---------|----------|
| `not_found_node` | Node ID does not exist in the workflow | Use `floless workflow nodes --workflow current --json` to list valid IDs |
| `not_found_workflow` | Workflow ID not found in desktop | Use `floless workflow list --json` to list loaded workflows |
| `invalid_workflow` | Workflow JSON failed schema validation | Fix the .flo JSON per `floless schema --type workflow` |
| `payload_too_large` | Request body exceeds size limit | Split into smaller batches or reduce code/workflow size |
| `length_required` | Content-Length header missing (empty body on POST requiring content) | Ensure stdin or `--input`/`--code` is provided |
| `unauthorized` | Bearer token mismatch — desktop restarted, changing the token | Run `floless start` to refresh the port file |
| `desktop_not_reachable` | Port file found but HTTP request timed out (30-second timeout) | Check if the desktop is frozen; restart with `floless start` |
| `conflict_dirty_workflow` | `workflow open` blocked by unsaved changes | Use `--force` flag to discard changes, or `floless workflow save` first |
| `conflict_no_current_path` | `workflow save` called on an Untitled workflow | Use `floless workflow save-as --output <path>` instead |

Parse `errorWrapper.details` for structured context — the fields inside vary by error code
(e.g., `details.nodeId` for `not_found_node`, `details.limitBytes` for `payload_too_large`).

## The compile gotcha

> **WARNING: `success: true` does NOT mean compilation succeeded.**

The `floless compile` command uses the same envelope as all other commands. `success: true` means
only that the API call reached the desktop and returned a valid response. **You must additionally
check `data.compiled` (boolean) to determine whether the Roslyn pipeline accepted the code.**

```json
{
  "success": true,
  "data": {
    "compiled": false,
    "diagnostics": [
      {
        "severity": "Error",
        "id": "CS0246",
        "message": "The type or namespace name 'Foo' could not be found",
        "line": 12,
        "column": 9
      }
    ],
    "nodeUpdated": false
  }
}
```

**Correct check pattern:**

```bash
RESULT=$(floless compile --code MyNode.cs --json)
SUCCESS=$(echo "$RESULT" | jq -r '.success')
COMPILED=$(echo "$RESULT" | jq -r '.data.compiled')

if [ "$SUCCESS" = "true" ] && [ "$COMPILED" = "true" ]; then
  echo "Compilation succeeded"
else
  echo "Compilation failed"
  echo "$RESULT" | jq '.data.diagnostics[]'
fi
```

Diagnostics array fields: `severity` (Error/Warning), `id` (e.g., CS0246), `message`, `line`,
`column`. Errors are also written to stderr by the CLI in MSBuild format when `--json` is not
used, but with `--json` they appear only in `data.diagnostics[]`.

This is the #1 skill-content gotcha. See also `references/command-reference.md` under `compile`.

## Desktop lifecycle — floless start and floless close

### floless start

Launches the FloLess desktop app and waits until its HTTP API is responsive. Idempotent: if the
desktop is already running (valid port file + live PID), returns success immediately without
spawning a second instance.

```bash
# Basic: launch and wait (up to 30 seconds)
floless start --json

# Load a workflow on startup
floless start --file my-workflow.flo --json

# Skip readiness poll (fire-and-forget)
floless start --no-wait --json

# Extend timeout for slow machines
floless start --timeout 60 --json
```

Options: `--file`, `--no-wait`, `--timeout <seconds>` (default 30), `--json`.

On success (`success: true`), the port file is now valid and all other commands can proceed.

**Note:** If the desktop is already running and `--file` is provided, the `--file` flag is ignored
with a warning. Use `floless workflow open --file {path}` to load a file into a running instance.

### floless close

Requests the desktop to shut down gracefully. Returns success once the desktop acknowledges the
shutdown request.

```bash
floless close --json
```

Options: `--json`.

After `floless close` returns, the port file is deleted by the desktop. Any subsequent `floless`
command will return exit 1 (connection refused / port file missing).

### Recovery chain: any port-file failure mode → floless start

Regardless of which port-file failure mode you encounter (missing, corrupt JSON, dead PID),
`floless start` is the universal recovery:

```bash
floless start --json   # Clears stale file, launches fresh desktop, writes new port file
```

## Stdin patterns

Some commands read from stdin when their file option is omitted:

| Command | Stdin used when | Option |
|---------|----------------|--------|
| `floless compile` | `--code` omitted | `--code <file>` |
| `floless workflow create` | `--input` omitted | `--input <file>` |

**Never call these commands without either the file option or piped stdin.** If stdin is a TTY
(interactive terminal) and neither option is provided, the process will block waiting for input
and appear to hang.

```bash
# Safe: pipe from file
cat MyNode.cs | floless compile --json
floless compile --code MyNode.cs --json

# Safe: use file flag
floless workflow create --input workflow.json --output out.flo --json

# Dangerous: hangs if stdin is a TTY
floless compile --json          # blocks
floless workflow create --output out.flo --json   # blocks
```

## Full command reference

The exhaustive reference for all 27 shipping commands — including exact option names, sample
output envelopes, and source line references — is in:

`references/command-reference.md`

## Progressive disclosure

What lives in this SKILL.md body:
- Connection pattern (port file, discovery, failure modes)
- Envelope shape and parsing rules
- Exit codes and size limits
- Common error codes and their recovery
- Compile gotcha (the #1 trap for AI agents)
- Desktop lifecycle (`floless start` / `floless close`)
- Stdin patterns

What lives in `references/command-reference.md`:
- Every command's exact option names and syntax
- Sample output envelopes per command
- Source file and line number references
- Workflow subcommand distinctions (open vs. export vs. save-as)

## Cross-skill links

| Skill | When to follow |
|-------|---------------|
| `floless-workflows` | You need `.flo` file format, Flow A (build from scratch), Flow B (augment loaded workflow), or workflow execution control (`run`/`stop`) |
| `floless-smart-nodes` | You need the compile-fix loop, C# code patterns, `nodeUpdated` semantics, or target framework selection |
| `floless-think-nodes` | You need LLM prompt/model/temperature configuration or `update-think-node` usage |
| `floless-triggers` | You need the 45+ trigger types, per-trigger configuration, or provider-specific behavior |
| `floless-canvas` | You need X/Y positioning, port index semantics, or layout best practices |
| `floless-overview` | You need the conceptual entry: what FloLess is, node taxonomy, Flow A vs B, first-workflow walkthrough |

**Scope boundary:** This skill owns CLI mechanics, the connection layer, and the response envelope.
It does NOT own `.flo` file format (workflows), C# compile patterns beyond the envelope gotcha
(smart-nodes), LLM prompt templates (think-nodes), trigger catalogs (triggers), or node
positioning (canvas).
