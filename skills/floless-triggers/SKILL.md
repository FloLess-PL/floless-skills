---
name: floless-triggers
description: Discover and configure FloLess trigger nodes. Use when picking a trigger for a workflow, setting trigger fields, referencing trigger output in downstream nodes, or understanding provider-specific trigger behavior. Covers 45+ trigger types grouped by provider: Excel (cell change), File (folder watcher), Schedule (cron/interval), Email (IMAP), Tekla (drawing events, model events, selection events, clash events), and Trimble Connect (BCF topics). Run `floless triggers --json` to list all triggers or `floless triggers --json --provider <name>` to filter by provider.
license: MIT
compatibility: Requires FloLess desktop app running and floless CLI installed. Windows only.
metadata:
  author: FloLess
  version: "1.0.0"
  cli-version-min: "1.0.0"
allowed-tools: Bash(floless:*) Read
---

# floless-triggers

FloLess triggers start workflows. Every workflow needs exactly one trigger. This skill catalogs
the 45+ trigger types and teaches the discovery pattern, configuration fields, and variable
templating from trigger output — so you can pick the right trigger and configure it correctly
without digging through source files.

## How to reach the FloLess CLI

1. Prerequisite: FloLess desktop app running on Windows (`floless start` to launch).
2. The CLI discovers the port file at `%LocalAppData%\FloLess\cli-api.port`.
3. Every command supports `--json`; always use it from AI terminals.
4. Envelope shape: `{success, data, count?, error?, errorCode?, errorWrapper?}` (Stripe-style).
5. Full CLI reference: see the `floless-cli` skill.

## When to use this skill

- You need to start a workflow based on an event (file created, cell changed, model saved, etc.)
- You want to understand what output variables a trigger emits so downstream nodes can reference them
- You are narrowing from "I want to react to Tekla changes" to a specific trigger ID
- You need to know which fields a trigger requires before configuring it in a workflow

For how triggers plug into a workflow JSON, see `floless-workflows`. For canvas placement
(triggers always sit at x ≈ 0, leftmost position), see `floless-canvas`.

## Discovering triggers

### List all triggers

```bash
floless triggers --json
```

Returns an envelope with `data` as an array of trigger objects. Each object includes:
`componentId`, `name`, `providerName`, `parameters` (array).

### Filter by provider

```bash
floless triggers --json --provider <name>
```

The `--provider` flag does a **case-insensitive substring match** on `providerName`. This means:

- `floless triggers --json --provider tekla` matches both "Tekla Drawing" and "Tekla Model" providers
- `floless triggers --json --provider excel` matches only Excel triggers
- `floless triggers --json --provider trimble` matches only Trimble Connect triggers

**Provider name substrings** (use with `--provider`):

| Substring | Matches |
|-----------|---------|
| `excel` | Excel triggers |
| `file` | File / folder watcher triggers |
| `system` | Scheduled trigger |
| `email` | Email (IMAP) triggers |
| `tekla` | All Tekla triggers (both Drawing and Model categories) |
| `trimble` | Trimble Connect triggers |

### Search by keyword

```bash
floless triggers --json | jq '.data[] | select(.name | ascii_downcase | contains("drawing"))'
```

### Fetch full schema for a specific trigger

```bash
floless component <trigger-id> --json
```

Example:

```bash
floless component excel-cell-changed --json
```

This returns the full JSON definition including all parameters with types, defaults, and
dependency rules.

## Anatomy of a trigger config

Every trigger has:

- **ID** — kebab-case identifier used in workflow JSON (e.g., `excel-cell-changed`)
- **Parameters** — configuration fields the user fills in on the canvas; some are required, some optional
- **Outputs** — variables emitted at runtime; downstream nodes reference them via `{{trigger.<fieldName>}}`

Parameters have types: `string`, `number`, `boolean`, `dropdown`, `file-picker`, `folder-picker`,
`cron`, `timezone`, `chip-select`, `tree`. The `dependsOn` property means a field is only
relevant when another parameter has a specific value.

## Per-provider quick tour

### Excel — 1 trigger

**`excel-cell-changed`** — Triggers when a specific cell in an Excel file is modified.

Required config fields:
- `filePath` (file-picker) — path to the .xlsx file
- `cellAddress` (string) — cell address to monitor, e.g., `A1`

Optional config fields:
- `sheetName` (string, default: `Sheet1`) — worksheet name
- `triggerOnSave` (boolean, default: false) — when OFF uses real-time detection (requires Excel
  open); when ON checks only on file save

Output variables available in downstream nodes:
- `{{trigger.cellValue}}` — current value of the monitored cell
- `{{trigger.previousValue}}` — value before the change
- `{{trigger.cellAddress}}` — address of the changed cell
- `{{trigger.sheetName}}` — worksheet name
- `{{trigger.filePath}}` — path to the Excel file
- `{{trigger.lastModified}}` — timestamp of last file modification

Example use case: watch cell B2 on Sheet1 of a project status file; when the value changes,
update a Tekla user property.

### File — 1 trigger

**`folder-watcher`** — Triggers when files are created, modified, deleted, or renamed in a folder.
Supports file stability detection for transmittal workflows.

Required config fields:
- `folderPath` (folder-picker) — the folder to monitor

Key optional config fields:
- `includeSubfolders` (boolean, default: true) — recursive monitoring
- `fileExtensions` (string) — comma-separated without dots, e.g., `pdf,xlsx,dwg`
- `fileNamePattern` (string) — wildcard pattern, e.g., `Report_*.pdf`
- `changeTypes` (chip-select, default: ALL) — CREATED / MODIFIED / DELETED / RENAMED
- `stabilityMode` (dropdown, default: NONE) — NONE / SIZE_STABLE / MARKER_FILE / FILE_COUNT / FILE_UNLOCKED
- `debounceDelay` (number, default: 500ms) — delay before triggering to batch rapid events
- `batchMode` (boolean, default: false) — collect multiple files into one trigger event

Output variables:
- `{{trigger.filePath}}` — full path to the changed file
- `{{trigger.fileName}}` — file name only
- `{{trigger.fileNameWithoutExtension}}` — file name without extension
- `{{trigger.extension}}` — file extension without the dot
- `{{trigger.changeType}}` — CREATED / MODIFIED / DELETED / RENAMED
- `{{trigger.folderPath}}` — path to containing folder
- `{{trigger.relativePath}}` — path relative to the watched folder
- `{{trigger.fileSize}}` — file size in bytes
- `{{trigger.timestamp}}` — ISO 8601 timestamp of the event
- `{{trigger.files}}` — array of changed files in batch mode
- `{{trigger.fileCount}}` — count in batch mode

Gotcha: File triggers can emit thousands of events on bulk operations such as a transmittal
drop. Use `debounceDelay`, `stabilityMode`, and `batchMode` to control this.

### Schedule — 1 trigger

**`scheduled-trigger`** — Triggers at scheduled intervals or via cron expression.

Required config fields:
- `scheduleMode` (dropdown) — `interval` (simple) or `cron` (advanced)
- `timezone` (timezone, default: UTC)

Fields for `interval` mode:
- `intervalValue` (number, default: 5)
- `intervalUnit` (dropdown) — seconds / minutes / hours / days

Fields for `cron` mode:
- `cronExpression` (cron) — standard 5-field cron, e.g., `*/5 * * * *` (every 5 min),
  `0 9 * * 1-5` (weekdays at 9am)

Other optional fields:
- `preventOverlap` (boolean, default: true) — skip execution if previous run still in progress
- `runImmediately` (boolean, default: true) — run immediately on start, then continue on schedule
- `runOnce` (boolean, default: false) — execute only once then stop

Output variables:
- `{{trigger.timestamp}}` — ISO 8601 when the trigger fired
- `{{trigger.scheduledTime}}` — the originally scheduled time
- `{{trigger.nextScheduledTime}}` — next scheduled execution
- `{{trigger.executionCount}}` — how many times this trigger has fired since workflow start

### Email — 1 trigger

**`email-received`** — Triggers when a new email is received (IMAP polling).

Note: Email account credentials are configured in FloLess Settings, not in this trigger's parameters.

Config fields:
- `folder` (string, default: INBOX) — IMAP folder name
- `limit` (number, default: 10) — max emails to fetch per poll
- `unreadOnly` (boolean, default: true) — only fetch unread emails
- `subjectFilter` (string) — text that must appear in email subject (e.g., `RFI`)
- `fromFilter` (string) — filter by sender address(es); space-separated for OR logic
- `pollingInterval` (number, default: 30) — seconds between polls

Minimum polling interval is typically 30 seconds. Do not set below 30.

Output variables:
- `{{trigger.subject}}` — email subject line
- `{{trigger.bodyText}}` — plain text body
- `{{trigger.bodyHtml}}` — HTML body
- `{{trigger.from}}` — sender email address
- `{{trigger.fromName}}` — sender display name
- `{{trigger.to}}` — recipient addresses (comma-separated)
- `{{trigger.receivedDate}}` — ISO 8601 received timestamp
- `{{trigger.hasAttachments}}` — boolean, true if attachments present
- `{{trigger.attachmentNames}}` — comma-separated attachment filenames
- `{{trigger.messageId}}` — unique message identifier

### Tekla — 33 triggers

Tekla triggers react to events from Tekla Structures running on the same machine. Most have
no configuration parameters — they fire on the event itself.

**Thread safety note:** Most Tekla events are handled asynchronously. The exception is
`tekla-model-unloading-sync`, which runs on the main Tekla thread — workflows using it
MUST complete quickly to avoid blocking Tekla. See the `floless-triggers` user memory for
full threading details.

**Prerequisite:** Tekla Structures must be running on the same Windows machine as FloLess.
Tekla triggers cannot be used with a remote Tekla instance.

**Drawing events** (7 triggers):
- `tekla-drawing-loaded` — drawing finishes loading
- `tekla-drawing-changed` — drawing content modified and committed
- `tekla-drawing-deleted` — drawing deleted
- `tekla-drawing-inserted` — new drawing inserted
- `tekla-drawing-ready-for-issuing-changed` — drawing's issuable status changes
- `tekla-drawing-interrupted` — drawing operation interrupted
- `tekla-drawing-status-changed` — drawing status changes

All drawing event triggers emit: `{{trigger.drawingName}}`, `{{trigger.drawingType}}`,
`{{trigger.drawingMark}}`, `{{trigger.drawingTitle}}`, `{{trigger.drawingStatus}}`,
`{{trigger.timestamp}}`.

**Drawing editor events** (3 triggers):
- `tekla-drawing-editor-opened` — drawing editor window opened
- `tekla-drawing-editor-closed` — drawing editor window closed
- `tekla-drawing-document-manager-closed` — document manager closed

**Drawing selection events** (3 triggers):
- `tekla-drawing-selection-changed` — selection changes within the drawing editor
- `tekla-drawing-list-selection-changed` — selection changes in the drawing list
- `tekla-annotation-selection-changed` — annotation selection changes

**Model events** (9 triggers):
- `tekla-model-loaded` — model opened; emits `{{trigger.modelName}}`, `{{trigger.modelPath}}`
- `tekla-model-saved` — model saved
- `tekla-model-saved-as` — model saved with a new name
- `tekla-model-save-info` — model save operation details
- `tekla-model-load-info` — model load operation details
- `tekla-model-unloading` — model closing (async)
- `tekla-model-unloading-sync` — model closing (SYNC — workflows must be fast)
- `tekla-objects-changed` — model objects created / modified / deleted / user-property changed;
  emits rich output including GUIDs grouped by change type
- `tekla-object-numbered` — object numbering assigned

**Model view and state events** (6 triggers):
- `tekla-selection-changed` — model view selection changes; emits `{{trigger.selectedGuids}}`,
  `{{trigger.count}}`
- `tekla-clip-plane-changed` — clip plane modified in model view
- `tekla-view-camera-changed` — camera position changes in model view
- `tekla-view-closed` — model view closed
- `tekla-temporary-states-changed` — temporary states (phases, filters) change
- `tekla-hidden-objects-changed` — object visibility changes

**Clash events** (2 triggers):
- `tekla-clash-detected` — fires for each individual clash found; emits `{{trigger.object1Guid}}`,
  `{{trigger.object2Guid}}`, `{{trigger.clashType}}`, `{{trigger.overlap}}`
- `tekla-clash-check-complete` — fires when the full clash check finishes; emits `{{trigger.clashCount}}`

**Other Tekla events** (3 triggers):
- `tekla-numbering-complete` — numbering operation finishes; emits `{{trigger.modelName}}`
- `tekla-command-status-changed` — a command changes state
- `tekla-undo` — user performs undo
- `tekla-exit` — Tekla Structures is closing
- `tekla-project-info-changed` — project information modified

For any Tekla trigger's full config schema, run:

```bash
floless component <trigger-id> --json
```

### Trimble Connect — 4 triggers

Trimble Connect triggers poll the cloud BCF platform for topic and comment events.
Credentials must be configured in FloLess Settings > Integrations > Trimble Connect before use.
All Trimble Connect triggers are polling-based (default: 60-second interval).

- **`trimble-connect-topic-created`** — fires when a new topic is created; emits `{{trigger.topicId}}`,
  `{{trigger.title}}`, `{{trigger.topicType}}`, `{{trigger.createdBy}}`
- **`trimble-connect-topic-assigned`** — fires when a topic is assigned to a user; emits
  `{{trigger.topicId}}`, `{{trigger.assignedTo}}`, `{{trigger.previousAssignee}}`
- **`trimble-connect-topic-status-changed`** — fires when a topic's status changes; emits
  `{{trigger.topicId}}`, `{{trigger.previousStatus}}`, `{{trigger.newStatus}}`
- **`trimble-connect-comment-added`** — fires when a comment is added to a topic; emits
  `{{trigger.topicId}}`, `{{trigger.commentText}}`, `{{trigger.commentAuthor}}`

Config field available on all Trimble Connect triggers:
- `projectId` (dropdown, optional) — override the default project; populated dynamically from
  your Trimble Connect projects
- `pollingInterval` (number, default: 60) — seconds between polls

## Referencing trigger output in downstream nodes

Every trigger emits output variables. Downstream nodes reference them using the
`{{trigger.<fieldName>}}` syntax in their configuration.

Example — an `excel-cell-changed` trigger feeding into an action node:

```json
{
  "componentId": "some-action-id",
  "config": {
    "message": "Cell {{trigger.cellAddress}} on {{trigger.sheetName}} changed to {{trigger.cellValue}}"
  }
}
```

This skill documents the **source** of each variable (what each trigger emits). For how the
runtime interpolates these variables at execution time, see `floless-workflows`.

## Discovery flow

Recommended 3-step approach when a user describes an event:

1. **Narrow by domain** — run `floless triggers --json --provider <guess>` to see triggers
   for the likely provider. Use `tekla` for anything Tekla-related, `excel` for spreadsheet
   events, `file` for filesystem events.

2. **Search by keyword** if domain is unclear:
   ```bash
   floless triggers --json | jq '.data[] | select(.name | ascii_downcase | contains("drawing"))'
   ```

3. **Fetch full schema** for the chosen trigger:
   ```bash
   floless component <trigger-id> --json
   ```
   This returns the authoritative parameter list with types, defaults, dependency rules,
   and output schema.

## Progressive disclosure

The per-trigger schemas documented here are summaries from the source JSON. For the exhaustive
catalog of all 45 triggers with full config schemas and minimal examples, see
[references/trigger-catalog.md](references/trigger-catalog.md).

For any single trigger's live schema, always prefer `floless component <trigger-id> --json`
over this static documentation.

## Gotchas

**Tekla triggers require local Tekla.** Tekla Structures must run on the same Windows machine
as FloLess. Remote Tekla connections are not supported.

**File triggers and bulk operations.** When hundreds of files are dropped into a watched folder
at once, the `folder-watcher` trigger fires once per file. Use `debounceDelay` (500–2000ms) and
`batchMode` to collect events. For transmittals, use `stabilityMode: SIZE_STABLE` or
`MARKER_FILE` to ensure files are fully copied before triggering.

**Email minimum poll interval.** The `email-received` trigger defaults to 30-second polling.
Setting `pollingInterval` below 30 may exceed IMAP server rate limits.

**Trimble Connect requires credentials.** All `trimble-connect-*` triggers require Trimble
Connect credentials configured in FloLess Settings before they will authenticate.

**`tekla-model-unloading-sync` is synchronous.** This trigger runs on the Tekla main thread.
Workflows using it must complete within milliseconds. Use only for fast, critical cleanup
operations.

**`tekla-drawing-changed` vs `tekla-objects-changed`.** Drawing events relate to the drawing
document (the 2D sheet). Object events relate to the 3D model. Use the correct category
for your scenario.

## Cross-skill links

- **`floless-cli`** — CLI envelope shape, port file discovery, exit codes, full command reference
- **`floless-workflows`** — how triggers connect to action nodes in workflow JSON, variable
  runtime interpolation semantics, Flow A/B patterns
- **`floless-canvas`** — trigger node is always leftmost on the canvas (x ≈ 0), port index
  semantics, layout best practices
