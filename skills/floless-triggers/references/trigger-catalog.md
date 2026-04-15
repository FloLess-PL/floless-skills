# Trigger catalog

This catalog documents all 45 FloLess trigger types grouped by provider. Each entry lists the
trigger ID, description, configuration fields, and output variables available in downstream nodes.

For the authoritative live schema of any trigger, run:

```bash
floless component <trigger-id> --json
```

## How this catalog is organized

Each trigger entry contains:
- **ID** — the kebab-case identifier used in workflow JSON and `floless component` queries
- **Provider** — the provider category (used with `--provider` filter)
- **Description** — what event fires this trigger
- **Config fields** — parameters the user configures (R = required, O = optional)
- **Output variables** — available as `{{trigger.<fieldName>}}` in downstream nodes

---

## Excel triggers

### excel-cell-changed

**Provider:** Excel
**Description:** Triggers when a specific cell in an Excel file is modified.
**Discovery:** `floless triggers --json --provider excel`

Config fields:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `filePath` | file-picker | R | — | Path to the .xlsx file |
| `cellAddress` | string | R | — | Cell address, e.g., `A1`, `B5` |
| `sheetName` | string | O | `Sheet1` | Worksheet name |
| `triggerOnSave` | boolean | O | false | OFF = real-time (Excel must be open); ON = on file save only |

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.cellValue}}` | string | Current value of the monitored cell |
| `{{trigger.previousValue}}` | string | Value before the change |
| `{{trigger.cellAddress}}` | string | Address of the changed cell |
| `{{trigger.sheetName}}` | string | Worksheet name |
| `{{trigger.filePath}}` | string | Path to the Excel file |
| `{{trigger.lastModified}}` | string | ISO 8601 timestamp of last file modification |

Minimal example — forward cell value to a notification action:

```json
{
  "componentId": "excel-cell-changed",
  "config": {
    "filePath": "C:\\Projects\\status.xlsx",
    "cellAddress": "B2",
    "sheetName": "Sheet1"
  }
}
```

Downstream reference: `{{trigger.cellValue}}`, `{{trigger.sheetName}}`

---

## File triggers

### folder-watcher

**Provider:** File
**Description:** Triggers when files are created, modified, deleted, or renamed in a folder.
Supports file stability detection for transmittal workflows.
**Discovery:** `floless triggers --json --provider file`

Config fields:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `folderPath` | folder-picker | R | — | Folder to monitor |
| `includeSubfolders` | boolean | O | true | Recursive monitoring |
| `fileExtensions` | string | O | — | Comma-separated without dots: `pdf,xlsx,dwg` |
| `fileNamePattern` | string | O | `*` | Wildcard: `Report_*.pdf` |
| `changeTypes` | chip-select | O | ALL | ALL / CREATED / MODIFIED / DELETED / RENAMED |
| `stabilityMode` | dropdown | O | NONE | NONE / SIZE_STABLE / MARKER_FILE / FILE_COUNT / FILE_UNLOCKED |
| `stabilityTimeout` | number | O | 1000 | Milliseconds file must be unchanged (when stabilityMode != NONE) |
| `markerFileName` | number | O | — | e.g., `COMPLETE.txt` (when stabilityMode = MARKER_FILE) |
| `expectedFileCount` | number | O | 1 | (when stabilityMode = FILE_COUNT) |
| `debounceDelay` | number | O | 500 | Milliseconds to wait before triggering |
| `batchMode` | boolean | O | false | Collect multiple events into one trigger |
| `minFileSize` | number | O | 0 | Ignore files smaller than N bytes |
| `maxFileSize` | number | O | 0 | Ignore files larger than N bytes (0 = no limit) |

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.filePath}}` | string | Full path to the changed file |
| `{{trigger.fileName}}` | string | File name only (with extension) |
| `{{trigger.fileNameWithoutExtension}}` | string | File name without extension |
| `{{trigger.extension}}` | string | Extension without the dot |
| `{{trigger.folderPath}}` | string | Path to containing folder |
| `{{trigger.relativePath}}` | string | Path relative to watched folder |
| `{{trigger.changeType}}` | string | CREATED / MODIFIED / DELETED / RENAMED |
| `{{trigger.oldFilePath}}` | string | Previous path (RENAMED events only) |
| `{{trigger.oldFileName}}` | string | Previous file name (RENAMED events only) |
| `{{trigger.fileSize}}` | number | File size in bytes (0 for deleted files) |
| `{{trigger.lastModified}}` | datetime | ISO 8601 last-modified timestamp |
| `{{trigger.createdAt}}` | datetime | ISO 8601 creation timestamp |
| `{{trigger.timestamp}}` | datetime | ISO 8601 when the trigger fired |
| `{{trigger.files}}` | array | Changed files in batch mode |
| `{{trigger.fileCount}}` | number | Number of files in batch event |

---

## Schedule triggers

### scheduled-trigger

**Provider:** System
**Description:** Triggers at scheduled intervals or on a cron expression. Use for time-based workflows.
**Discovery:** `floless triggers --json --provider system`

Config fields:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `scheduleMode` | dropdown | R | `interval` | `interval` (simple) or `cron` (advanced) |
| `timezone` | timezone | R | UTC | IANA timezone name |
| `intervalValue` | number | O | 5 | Number of units (interval mode only) |
| `intervalUnit` | dropdown | O | minutes | seconds / minutes / hours / days (interval mode only) |
| `cronExpression` | cron | O | — | 5-field cron, e.g., `*/5 * * * *` (cron mode only) |
| `preventOverlap` | boolean | O | true | Skip if previous run still in progress |
| `runImmediately` | boolean | O | true | Run immediately on start, then on schedule |
| `runOnce` | boolean | O | false | Execute only once then stop |

Common cron examples:
- `*/5 * * * *` — every 5 minutes
- `0 9 * * 1-5` — weekdays at 9am
- `0 0 * * *` — daily at midnight
- `0 8 1 * *` — 1st of every month at 8am

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.timestamp}}` | datetime | ISO 8601 when the trigger fired |
| `{{trigger.scheduledTime}}` | datetime | Originally scheduled time |
| `{{trigger.nextScheduledTime}}` | datetime | Next scheduled execution |
| `{{trigger.executionCount}}` | number | Times fired since workflow started |

---

## Email triggers

### email-received

**Provider:** Email
**Description:** Triggers when a new email is received in the monitored IMAP folder.
Polls on interval; credentials configured in FloLess Settings.
**Discovery:** `floless triggers --json --provider email`

Config fields:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `folder` | string | O | INBOX | IMAP folder name |
| `limit` | number | O | 10 | Max emails to fetch per poll |
| `unreadOnly` | boolean | O | true | Only fetch unread emails |
| `subjectFilter` | string | O | — | Text that must appear in subject |
| `fromFilter` | string | O | — | Sender filter; space-separated for OR logic |
| `pollingInterval` | number | O | 30 | Seconds between polls; minimum 30 |

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.messageId}}` | string | Unique message identifier |
| `{{trigger.subject}}` | string | Email subject line |
| `{{trigger.from}}` | string | Sender email address |
| `{{trigger.fromName}}` | string | Sender display name |
| `{{trigger.to}}` | string | Recipient addresses (comma-separated) |
| `{{trigger.cc}}` | string | CC recipients (comma-separated) |
| `{{trigger.bodyText}}` | string | Plain text body |
| `{{trigger.bodyHtml}}` | string | HTML body |
| `{{trigger.receivedDate}}` | string | ISO 8601 received timestamp |
| `{{trigger.hasAttachments}}` | boolean | True if email has attachments |
| `{{trigger.attachmentCount}}` | number | Number of attachments |
| `{{trigger.attachmentNames}}` | string | Comma-separated attachment filenames |

---

## Tekla triggers

Tekla triggers react to Tekla Structures events on the same Windows machine.
Most have no configuration parameters — they fire on the event.

**Thread safety:** Most Tekla events fire asynchronously. Exception: `tekla-model-unloading-sync`
runs on the Tekla main thread — keep workflows using it fast.

**Prerequisite:** Tekla Structures must be running locally. Remote Tekla is not supported.

**Discovery:** `floless triggers --json --provider tekla` (matches both Tekla Drawing and Tekla Model)

For a specific trigger's full schema: `floless component <trigger-id> --json`

### Drawing events

Drawing events fire when changes occur to the drawing document (2D sheet), not the 3D model.

**Shared output variables** (all drawing events emit these 6 variables):
`{{trigger.drawingName}}`, `{{trigger.drawingType}}` (GA/SinglePart/Assembly/CastUnit/Multi),
`{{trigger.drawingMark}}`, `{{trigger.drawingTitle}}`,
`{{trigger.drawingStatus}}` (UpToDate/NotUpToDate/DrawingIsUpToDateButMayNeedChecking),
`{{trigger.timestamp}}`

| Trigger ID | Description | Extra outputs |
|------------|-------------|---------------|
| `tekla-drawing-loaded` | Drawing finishes loading | — |
| `tekla-drawing-changed` | Drawing content modified and committed | — |
| `tekla-drawing-deleted` | Drawing deleted | — |
| `tekla-drawing-inserted` | New drawing created | — |
| `tekla-drawing-updated` | Catch-all: insert, modify, or delete | `{{trigger.updateType}}` (Inserted/Modified/Deleted) |
| `tekla-drawing-status-changed` | Drawing status changes | — |
| `tekla-drawing-ready-for-issuing-changed` | Ready-for-issuing flag toggled | — |
| `tekla-drawing-interrupted` | Drawing operation interrupted | — |

No config parameters on any drawing event.

### Drawing editor and selection events

All have no config parameters.

| Trigger ID | Description | Outputs |
|------------|-------------|---------|
| `tekla-drawing-editor-opened` | Drawing editor opened | Shared drawing vars (6) |
| `tekla-drawing-editor-closed` | Drawing editor closed | Shared drawing vars (6) |
| `tekla-drawing-document-manager-closed` | Document manager window closed | Shared drawing vars (6) |
| `tekla-drawing-selection-changed` | Selection changes in drawing editor | Shared drawing vars (6) |
| `tekla-drawing-list-selection-changed` | Drawing selection changes in drawing list | Shared drawing vars (6) |
| `tekla-annotation-selection-changed` | Annotation selection changes | `{{trigger.timestamp}}` only |

"Shared drawing vars" = the 6 variables listed under Drawing events above.

### Model lifecycle events

#### tekla-model-loaded

**Description:** Fires when a Tekla Structures model is opened.

No config parameters.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.modelName}}` | Name of the loaded model |
| `{{trigger.modelPath}}` | Full path to the model folder |
| `{{trigger.timestamp}}` | ISO 8601 timestamp |

#### tekla-model-saved

**Description:** Fires when the user saves the model (Ctrl+S or File > Save).

No config parameters. Same output variables as `tekla-model-loaded`.

#### tekla-model-saved-as

**Description:** Fires when the user saves the model to a new location (File > Save As).

No config parameters.

Output variables:
- `{{trigger.modelName}}` — name after Save As
- `{{trigger.modelPath}}` — new path
- `{{trigger.previousPath}}` — original path before Save As
- `{{trigger.timestamp}}` — ISO 8601

#### tekla-model-load-info

**Description:** Fires after model load with additional load information.

No config parameters.

Output variables:
- `{{trigger.info}}` — additional load details
- `{{trigger.modelName}}`, `{{trigger.modelPath}}`, `{{trigger.timestamp}}`

#### tekla-model-save-info

**Description:** Fires after model save with additional save information.

No config parameters.

Output variables:
- `{{trigger.info}}` — additional save details
- `{{trigger.modelName}}`, `{{trigger.timestamp}}`

#### tekla-model-unloading

**Description:** Fires (async) when the user closes the model.

No config parameters. Same output variables as `tekla-model-loaded`.

#### tekla-model-unloading-sync

**Description:** Fires (SYNCHRONOUS) when the model is closing. Runs on the Tekla main thread.
Workflows using this trigger MUST complete within milliseconds to avoid blocking Tekla.

No config parameters. Same output variables as `tekla-model-loaded`.

### Model object events

#### tekla-objects-changed

**Description:** Fires when model objects are created, modified, deleted, or have user properties
changed. Provides rich output including GUIDs grouped by change type.

Config fields:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `changeTypes` | dropdown | O | ALL | ALL / OBJECT_INSERT / OBJECT_MODIFY / OBJECT_DELETE / USERPROPERTY_CHANGED |
| `objectTypes` | tree | O | [] | Filter by Tekla object type hierarchy |
| `changeSources` | dropdown | O | ALL | ALL / COMMIT / UNDO_REDO / ROLLBACK |
| `minimumCount` | number | O | 1 | Only trigger if at least N matching objects changed |
| `countFilteredOnly` | toggle | O | true | Count only type-filtered objects |

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.changeCount}}` | number | Total changed objects |
| `{{trigger.insertedCount}}` | number | Created objects |
| `{{trigger.modifiedCount}}` | number | Modified objects |
| `{{trigger.deletedCount}}` | number | Deleted objects |
| `{{trigger.userPropertyChangedCount}}` | number | Objects with user property changes |
| `{{trigger.guids}}` | string | Space-separated GUIDs of all changed objects |
| `{{trigger.insertedGuids}}` | string | Space-separated GUIDs of inserted objects |
| `{{trigger.modifiedGuids}}` | string | Space-separated GUIDs of modified objects |
| `{{trigger.deletedGuids}}` | string | Space-separated GUIDs of deleted objects |
| `{{trigger.changeSources}}` | string | Comma-separated: COMMIT / UNDO_REDO / ROLLBACK |
| `{{trigger.isFromUndoRedo}}` | boolean | True if changes are from undo/redo |
| `{{trigger.insertedByType}}` | object | Object type counts for inserted objects |
| `{{trigger.modifiedByType}}` | object | Object type counts for modified objects |
| `{{trigger.timestamp}}` | string | ISO 8601 timestamp |

#### tekla-object-numbered

**Description:** Fires when objects receive part marks or assembly marks during numbering.

No config parameters.

Output variables:
- `{{trigger.count}}` — number of objects that were numbered
- `{{trigger.guids}}` — space-separated GUIDs of numbered objects
- `{{trigger.timestamp}}`

#### tekla-numbering-complete

**Description:** Fires when a numbering operation completes.

No config parameters.

Output variables:
- `{{trigger.modelName}}`
- `{{trigger.timestamp}}`

### Selection events

#### tekla-selection-changed

**Description:** Fires when objects are selected or deselected in the model view.

Config fields: `objectTypes` (tree, optional) — filter by Tekla object type.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.selectedGuids}}` | Space-separated GUIDs of selected objects |
| `{{trigger.count}}` | Number of selected objects |
| `{{trigger.previousCount}}` | Number of objects in previous selection |
| `{{trigger.byType}}` | Count by type (e.g., `{"Beam": 3}`) |
| `{{trigger.typeHierarchies}}` | Type hierarchy per GUID |
| `{{trigger.subTypes}}` | Subtype per GUID (e.g., `{"guid": "Beam.COLUMN"}`) |
| `{{trigger.timestamp}}` | ISO 8601 timestamp |

### Clash events

#### tekla-clash-detected

**Description:** Fires for each individual clash detected during a clash check.

Config fields: `clashTypes` (dropdown, optional) — HARD_CLASH / SOFT_CLASH.

Output variables:

| Variable | Type | Description |
|----------|------|-------------|
| `{{trigger.object1Guid}}` | string | GUID of first clashing object |
| `{{trigger.object2Guid}}` | string | GUID of second clashing object |
| `{{trigger.clashType}}` | string | HARD_CLASH or SOFT_CLASH |
| `{{trigger.isHardClash}}` | boolean | True if objects physically penetrate |
| `{{trigger.isSoftClash}}` | boolean | True if clearance violation |
| `{{trigger.overlap}}` | number | Overlap/clearance measurement in model units |
| `{{trigger.hasData}}` | boolean | Whether clash data is available |
| `{{trigger.timestamp}}` | string | ISO 8601 timestamp |

#### tekla-clash-check-complete

**Description:** Fires when the full clash check operation finishes.

No config parameters.

Output variables:
- `{{trigger.clashCount}}` — total number of clashes found
- `{{trigger.timestamp}}` — ISO 8601 timestamp

### View events

#### tekla-clip-plane-changed

**Description:** Fires when clip planes are inserted, modified, or removed from views.

No config parameters.

Output variables:
- `{{trigger.viewId}}` — ID of the view
- `{{trigger.clipPlaneId}}` — ID of the clip plane
- `{{trigger.operation}}` — Insert / Modify / Delete
- `{{trigger.timestamp}}`

#### tekla-view-camera-changed

**Description:** Fires when the user changes camera position or angle in a model view.

No config parameters.

Output variables:
- `{{trigger.viewId}}` — ID of the view
- `{{trigger.viewGuid}}` — GUID of the view
- `{{trigger.timestamp}}`

#### tekla-view-closed

**Description:** Fires when a model view window is closed.

No config parameters.

Output variables:
- `{{trigger.viewId}}` — ID of the closed view
- `{{trigger.timestamp}}`

### Other Tekla events

#### tekla-command-status-changed

**Description:** Fires when a Tekla command starts or ends.

No config parameters.

Output variables:
- `{{trigger.commandName}}` — name of the command
- `{{trigger.commandParam}}` — command parameter if any
- `{{trigger.isActive}}` — whether command is now active
- `{{trigger.isStarting}}` — true if command is starting
- `{{trigger.isEnding}}` — true if command is ending
- `{{trigger.timestamp}}`

#### tekla-hidden-objects-changed

**Description:** Fires when objects are hidden or shown in the model view.

No config parameters. Output variable: `{{trigger.timestamp}}` only.

#### tekla-interrupted

**Description:** Fires when an operation is interrupted by the user (typically Escape key).

No config parameters. Output variable: `{{trigger.timestamp}}` only.

#### tekla-project-info-changed

**Description:** Fires when project information (name, number, client) is modified.

No config parameters.

Output variables:
- `{{trigger.modelName}}`
- `{{trigger.timestamp}}`

#### tekla-temporary-states-changed

**Description:** Fires when temporary states (phases, filters, visibility settings) change.

No config parameters. Output variable: `{{trigger.timestamp}}` only.

#### tekla-undo

**Description:** Fires when the user performs an undo operation (Ctrl+Z).

No config parameters. Output variable: `{{trigger.timestamp}}` only.

Use together with `tekla-objects-changed` to track model state changes including undo/redo.

#### tekla-exit

**Description:** Fires when Tekla Structures application is shutting down.

No config parameters. Output variable: `{{trigger.timestamp}}` only.

---

## Trimble Connect triggers

Trimble Connect triggers poll the cloud BCF platform for topic and comment events.
All are polling-based. Credentials must be configured in FloLess Settings > Integrations > Trimble Connect.

**Discovery:** `floless triggers --json --provider trimble`

Common config fields on all Trimble Connect triggers:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `projectId` | dropdown | O | (Settings default) | Override project; populated dynamically |
| `pollingInterval` | number | O | 60 | Seconds between polls |

### trimble-connect-topic-created

**Description:** Fires when a new BCF topic is created in the project.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.triggered}}` | Whether a new topic was detected |
| `{{trigger.topicId}}` | ID of the new topic |
| `{{trigger.title}}` | Topic title |
| `{{trigger.topicType}}` | Type (e.g., Issue, Request) |
| `{{trigger.topicStatus}}` | Status (e.g., Open) |
| `{{trigger.priority}}` | Priority level |
| `{{trigger.createdBy}}` | Email of creator |
| `{{trigger.createdAt}}` | ISO timestamp |

### trimble-connect-topic-assigned

**Description:** Fires when a topic is assigned to a user.

Additional config: `filterAssignee` (string, optional) — only trigger for assignments to this email.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.triggered}}` | Whether an assignment was detected |
| `{{trigger.topicId}}` | ID of the assigned topic |
| `{{trigger.title}}` | Topic title |
| `{{trigger.previousAssignee}}` | Previous assignee email (empty if unassigned before) |
| `{{trigger.assignedTo}}` | New assignee email |
| `{{trigger.modifiedBy}}` | Email of user who made the assignment |
| `{{trigger.assignedAt}}` | ISO timestamp |

### trimble-connect-topic-status-changed

**Description:** Fires when a topic's status changes (e.g., Open to Closed).

Additional config: `filterStatus` (dropdown, optional) — only trigger when status changes to this value.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.triggered}}` | Whether a status change was detected |
| `{{trigger.topicId}}` | ID of the topic |
| `{{trigger.title}}` | Topic title |
| `{{trigger.previousStatus}}` | Previous status value |
| `{{trigger.newStatus}}` | New status value |
| `{{trigger.modifiedBy}}` | Email of user who changed the status |
| `{{trigger.modifiedAt}}` | ISO timestamp |

### trimble-connect-comment-added

**Description:** Fires when a new comment is added to a topic.

Additional config: `topicId` (string, optional) — watch only a specific topic; leave empty for all.

Output variables:

| Variable | Description |
|----------|-------------|
| `{{trigger.triggered}}` | Whether a new comment was detected |
| `{{trigger.topicId}}` | ID of the topic |
| `{{trigger.topicTitle}}` | Title of the topic |
| `{{trigger.commentId}}` | ID of the new comment |
| `{{trigger.commentText}}` | Text content of the comment |
| `{{trigger.commentAuthor}}` | Email of the comment author |
| `{{trigger.createdAt}}` | ISO timestamp |

---

## Cross-reference table

Summary of all 45 triggers: ID, provider category, number of config fields, number of output variables.

| Trigger ID | Provider | Config fields | Output vars |
|------------|----------|---------------|-------------|
| `excel-cell-changed` | Excel | 4 | 6 |
| `folder-watcher` | File | 13 | 15 |
| `scheduled-trigger` | System | 8 | 4 |
| `email-received` | Email | 6 | 12 |
| `tekla-drawing-loaded` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-changed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-deleted` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-inserted` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-updated` | Tekla Drawing | 0 | 7 |
| `tekla-drawing-status-changed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-ready-for-issuing-changed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-interrupted` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-editor-opened` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-editor-closed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-document-manager-closed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-selection-changed` | Tekla Drawing | 0 | 6 |
| `tekla-drawing-list-selection-changed` | Tekla Drawing | 0 | 6 |
| `tekla-annotation-selection-changed` | Tekla Model | 0 | 1 |
| `tekla-model-loaded` | Tekla Model | 0 | 3 |
| `tekla-model-saved` | Tekla Model | 0 | 3 |
| `tekla-model-saved-as` | Tekla Model | 0 | 4 |
| `tekla-model-load-info` | Tekla Model | 0 | 4 |
| `tekla-model-save-info` | Tekla Model | 0 | 3 |
| `tekla-model-unloading` | Tekla Model | 0 | 3 |
| `tekla-model-unloading-sync` | Tekla Model | 0 | 3 |
| `tekla-objects-changed` | Tekla Model | 5 | 15 |
| `tekla-object-numbered` | Tekla Model | 0 | 3 |
| `tekla-numbering-complete` | Tekla Model | 0 | 2 |
| `tekla-selection-changed` | Tekla Model | 1 | 7 |
| `tekla-clash-detected` | Tekla Model | 1 | 8 |
| `tekla-clash-check-complete` | Tekla Model | 0 | 2 |
| `tekla-clip-plane-changed` | Tekla Model | 0 | 4 |
| `tekla-view-camera-changed` | Tekla Model | 0 | 3 |
| `tekla-view-closed` | Tekla Model | 0 | 2 |
| `tekla-command-status-changed` | Tekla Model | 0 | 6 |
| `tekla-hidden-objects-changed` | Tekla Model | 0 | 1 |
| `tekla-interrupted` | Tekla Model | 0 | 1 |
| `tekla-project-info-changed` | Tekla Model | 0 | 2 |
| `tekla-temporary-states-changed` | Tekla Model | 0 | 1 |
| `tekla-undo` | Tekla Model | 0 | 1 |
| `tekla-exit` | Tekla Model | 0 | 1 |
| `trimble-connect-topic-created` | Trimble Connect | 2 | 8 |
| `trimble-connect-topic-assigned` | Trimble Connect | 3 | 7 |
| `trimble-connect-topic-status-changed` | Trimble Connect | 3 | 7 |
| `trimble-connect-comment-added` | Trimble Connect | 3 | 7 |

**Total: 45 triggers across 6 provider categories.**
