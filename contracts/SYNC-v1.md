# Tinker companion sync v1

The desktop owns the ordered journal. The phone owns an independent SQLite store
and durable outbox. Only `note`, `task`, and `event` aggregates cross this service.
Every response contains `version: 1` and the QR-paired `server_id`. Timestamps use
UTC ISO 8601 (`2026-10-05T09:00:00Z`); recurrence expands in the event's IANA timezone.
Record IDs are opaque, retained unchanged, and unique within a domain. New IDs use
the desktop convention (`note_`/`task_`/`event_` plus lowercase UUID hex).

## Transport and pairing

Advertise `_tinker._tcp.local.` with version and desktop identity, never secrets.
Bind one selected RFC1918/link-local IPv4 interface. Public, wildcard, loopback
(except isolated tests), Tailscale and remote-service endpoints are rejected.
Clients also reject redirects and public QR/discovery addresses.

Pairing QR JSON contains `version`, `server_id`, `endpoint` (HTTPS IPv4 and port),
`certificate_sha256` (lowercase SHA-256 of certificate DER), `code`, and
`expires_at` (Unix seconds). Verify the exact certificate before sending the code.
`POST /v1/pair` body: `{"version":1,"code":"<scanned code>"}`. It returns
`version`, `server_id`, `peer_id`, and a random `credential`. Codes expire after
120 seconds, permit five attempts, and are single-use. Only one phone is paired
for milestone one. Subsequent calls use `Authorization: Bearer <credential>`.

Desktop identity/private key and credential hashes live in an owner-only config
directory, outside the content database and normal exports. The phone stores the
pairing only in device-only Keychain. Bonjour is an address hint; it cannot change
the pinned certificate or desktop identity. Unpair in the phone first to cancel
its notifications, then revoke on Fedora before replacing the phone. If the
Keychain save fails after exchange, revoke on Fedora and pair again.

## Graphs and revisions

A complete value is `{"kind":"note|task|event","record":{...},"reminders":[],
"exceptions":[]}`; deletion is JSON `null`. This includes every related reminder
and event exception in one atomic edit. `record` uses existing desktop columns,
with booleans represented as JSON booleans. `metadata_json` is JSON object text,
recursively checked by the structured-credential policy. Unknown fields fail.
See [snapshot-v1.json](snapshot-v1.json) for a shared, desktop-generated fixture.

Notes: `id,title,body,archived,pinned,created_at,updated_at,metadata_json`.
Tasks: `id,title,description,status,due_at,created_at,updated_at,metadata_json`.
Task statuses: `pending,in_progress,completed,cancelled`; `due_at` is nullable.
Events: `id,title,description,location,start_at,end_at,all_day,timezone,recurrence,
created_at,updated_at,metadata_json`. End is exclusive and must follow start.
`recurrence` is nullable. All-day UI saves midnight boundaries in the event timezone.

Reminder fields: `id,owner_kind,owner_id,fire_at,message,notification_owner,completed`.
Owner is `phone` or `desktop`, fixed once the reminder exists. Only that device
schedules it; changing devices requires a new reminder. Event reminders repeat at
their offset from DTSTART, respecting occurrence cancellation/movement.
Exception fields: `id,event_id,occurrence_at,cancelled,start_at,end_at,title`.
Optional fields are explicit nulls. Original occurrence identity never moves.
The original timestamp must be a real occurrence. Children cannot move across
parents or reuse another parent's IDs.

`GET /v1/snapshot` returns `cursor,records,conflicts`. Each record contains
`kind,id,revision,value`; tombstones are retained indefinitely. Snapshot and cursor
are from one transaction. Desktop triggers observe legacy CRUD/import/reset, and
coalesce complete graphs into ordered revisions before a sync transaction.

`GET /v1/changes?after=<cursor>` returns `cursor,has_more,changes`, up to 200 entries.
Each change is `seq,kind,id,value`. Domain revisions equal their journal sequence.
`kind:"conflict"` carries a conflict object rather than a graph. Cursor advances
only after the phone commits the entire page. Future cursors fail explicitly;
restoring/replacing a paired desktop database requires recovery/re-pairing.

`POST /v1/upload` body: `{"version":1,"mutations":[...]}`. Each mutation contains
`op_id,kind,id,base_revision,value,resolve_id`; nullable values are explicit nulls.
At most 100 mutations, 4 MiB per request, 262144 UTF-8 bytes per text field, and
1000 children per parent. Upload is one SQLite transaction. An unknown parent's
base is zero. A tombstone has its own revision, so deleted IDs cannot silently
resurrect from stale offline writes.

Uploads return ordered `results`, each `op_id,status,revision,conflict` (`applied`
or `conflict`). Durable operation hashes/results make retries idempotent. Reusing
an operation ID with different content fails. The phone coalesces unsent edits per
parent; acknowledgement removes only the exact uploaded operation. If an edit is
made during upload, it remains queued and its base advances only after acceptance.

## Conflicts and reminders

A stale base preserves the live current version and incoming complete graph,
including edit/delete conflicts. Conflict object: `id,kind,record_id,current,
incoming,current_revision,resolved`. Both clients can inspect both copies.
Resolve with the conflict's inspected `current_revision` and `resolve_id`; do not
substitute a later unseen revision. A race creates a new open conflict and closes
the inspected one as superseded, retaining its full history in the database.
Resolved conflict changes remove it from the phone's active conflict list.
Pending local edits must sync before resolving another conflict for the same item.

Reminder request identity is stable reminder ID plus original occurrence instant.
Repeated foreground reconciliation replaces requests, rather than accumulating
notifications. Desktop deliveries are recorded before presentation and survive
restart. iOS keeps the next 60 upcoming phone reminders within 30 days and refills
on foreground/best-effort refresh. Notification permission, offline deletes on
another device, OS scheduling and periods without reopening can affect delivery;
this is single-owner deduplication, not a distributed exactly-once delivery claim.

## Recurrence and ICS scope

Support DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL 1–366, COUNT 1–10000 or UTC UNTIL,
and weekly distinct BYDAY weekdays. DTSTART always counts; weekly intervals use
Monday-based weeks. Preserve local wall time across DST, skip invalid month dates,
and bound expansion to 100 years. Unsupported recurrence components fail clearly.

ICS supports UTF-8 unfolding/folding (75 octets), escaped text, stable UID,
UTC/TZID/floating dates (import timezone), all-day DATE, the supported RRULE subset,
EXDATE, RECURRENCE-ID overrides, and one-shot DISPLAY alarms (absolute or negative
start-relative day/hour/minute/second durations). Unsupported RDATE, EXRULE,
DURATION and alarm types fail instead of being dropped. No CalDAV, external
calendar account, VTIMEZONE definition import or arbitrary RFC5545 support is
claimed. Exchange at most 100 parent events / 4 MiB per file. ICS represents active
alarms; it does not carry desktop metadata, notification ownership, sync history,
reminder IDs or completion history. Normal desktop JSON exports carry domain data.
