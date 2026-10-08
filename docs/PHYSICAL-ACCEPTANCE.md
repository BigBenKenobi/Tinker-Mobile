# Physical candidate acceptance

Prepared candidate: **build 59**, source `db007a3`.
[Unsigned IPA artifact](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37647505368/artifacts/11495155584).
Payload SHA256: `e6cf310924a79d1b7037eb1177075648801e84359dc3949123b25aeeb99573bb`.
See [current validation](validation/current.json) for the full source/digests/results.

Record the candidate source SHA/build number from Companion, the IPA payload
SHA256 from its manifest, desktop SHA, iPhone model/iOS version, installer/signing
method, date, and tester. A screenshot archive or Simulator result cannot fill
these entries. Leave each outcome pending until exercised on that build.

Before installing, prepare and save a recovery copy from the existing app if that
build supports it, otherwise preserve its app container using the existing trusted
installation workflow. Keep the bundle ID `com.bigbenkenobi.tinker-companion` and
install over the current app; uninstalling removes the local container.

| Check | Expected result | Outcome |
|---|---|---|
| Upgrade/relaunch | Existing notes, calendars, pending outbox and Keychain pairing remain | Pending |
| Offline edit/reconnect | Local edits survive restart and converge after desktop reconnect | Pending |
| Stale editor | Open an editor, change the item through sync/another action, then save; newer data stays and the draft remains open | Pending |
| Conflict choice | Both versions remain inspectable; a raced resolution preserves the newer desktop version | Pending |
| Multi-calendar ICS | Preview replacements; an existing event retains its calendar even when another target is chosen | Pending |
| Pending ICS replacement | Import cannot overwrite unsynced edits/deletions; no partial new events are added | Pending |
| Bad alarm input | Overflowing/malformed alarm file produces a recoverable error; existing data stays | Pending |
| Files and recovery | Export/import supported ICS; save recovery copy and verify it is readable without replacing the live store | Pending |
| Reminders | Ownership, due delivery, cancellation, recurring exceptions and repeated foreground refresh behave correctly | Pending |
| Permissions/reconnect | Camera/network/notification denial and recovery remain usable; certificate mismatch stays rejected | Pending |
| Accessibility/layout | VoiceOver, large text, keyboard, portrait/landscape, import review and recovery controls work | Pending |
| Battery/performance | Compare representative foreground/background use on the same device and dataset; record observations/timing | Pending |
| Signing refresh | Refresh the installed candidate and verify pairing/local data survive | Pending |

Record failures with reproducible steps and preserve drafts/recovery files. Do not
attach private record contents or pairing credentials to public issues.

Acceptance statement: **Pending owner verification and approval.**

## Step 13 current review handoff — 9 October 2026

Preparation is complete under approved Step 13. The build-59 identity above is historical and must be checked against the installed phone. Changed-source review candidate is a92b9b0cb40e6d6b8a4a40fe47fc23a6aa0378c0 (draft #7). Native run 37766716383/build 64 passes 48 unit + two UI smoke tests per Simulator (Xcode 16.4/iOS 18.5). Device job and screenshot export were skipped; this does not identify a physical install or a visual pass. Protocol 2 / desktop schema 5 / mobile SQLite schema 2 apply to the paired review.

Start with P01 identity/upgrade below and record actual source/build/signed hash, device/iOS, paired desktop identity, expected/actual outcome, sanitized evidence and reviewer in [the fillable manifest](validation/2026-10-09-handoff.json). Expand grouped rows into every required device/environment cell. Outcomes remain pending until executed; blocked/deferred cases need a reason and owner review, never a pass. Use isolated synthetic fixtures and the existing trusted backup/install workflow; do not uninstall or change signing identity. A new physical candidate build/install/signing action requires its separately authorized owner workflow.

| ID | Procedure / required outcome | Outcome |
|---|---|---|
| P01 | Record actual phone/iOS, installed bundle/source/build and signed artifact hash, signing method/expiry, prior build and paired desktop/source/hash. Back up through the existing trusted process. Upgrade over the same com.bigbenkenobi.tinker-companion identity without uninstalling; verify Notes/Tasks/Calendar, unsent outbox and Keychain pairing retained. Stop on identity mismatch or unsupported recovery. | Pending |
| P02 | Create/edit/delete offline, relaunch then reconnect; durable outbox replays once, cursor advances after commit, IDs/tombstones/graphs/order preserved. Record pending counts and final synthetic record states on both peers; interrupted sync, failure/cancel/retry cannot discard work. | Pending |
| P03 | Open stale editors, change records on peer, race save/delete and reconnect; conflicts preserve both versions and drafts. Explicit review resolution removes only resolved conflicts; bounded pages eventually expose all conflicts without quiet-sync scans. | Pending |
| P04 | Multiple calendars, recurring events and exceptions, selected-calendar ICS export/import through Files, duplicate/replacement preview, pending edits/deletes and change-after-preview, malformed/overflow alarm data: correct membership and reminder ownership, reject invalid data atomically and preserve originals/drafts. | Pending |
| P05 | Reminder ownership, granted/denied/revoked notification/local-network permissions, TLS pin mismatch, failed pairing, revoked peer and re-pair: clear feedback without data loss or credential leakage. Keychain is the only bearer store; record no tokens or QR text. | Pending |
| P06 | VoiceOver, keyboard where available, large Dynamic Type, small/large layout, foreground/background transitions, offline/quiet sync and battery observation. Record device, dataset size, duration, energy/memory/MainActor/storage/recurrence evidence; real-device restructuring remains issue #5, not an inferred performance pass. | Pending |
| P07 | Use the established owner signing/refresh procedure, retain same bundle identity and repeat renewal; confirm pairing, records and outbox survive. Record real expiry and renewals. Review sanitized screenshots and observed outcomes for the changed candidate before expiry; simulator screenshots or historical owner reports cannot accept this build. | Pending |

Original visual references, changed-candidate captures/visual review and minimum iOS 17 runtime remain pending. Latest full native bundles expire 22 October UTC, compact manifests 6 January 2027 UTC; historical unsigned build-59 payload expires 21 October 2026 15:53:24 UTC. [Curated regression evidence](validation/2026-10-09-handoff/native-regression.json) records inventory/excerpts only, not downloaded/reviewed binary evidence. Retain required source-matched results and sanitized captures before expiry. Mobile #4 remains open.

After separate acceptance/integration approval, proposed oldest-first order is #1 → #2 → #3 → #7 → Step 13 documentation draft; retarget only after each parent lands on main and recheck diff/ancestry/checks. [Integration/release preparation](INTEGRATION_RELEASE.md) records owner decisions, exact source heads, protection feasibility and post-integration validation. This checklist authorizes no merge, retirement, setting, tag, release or signing change.
