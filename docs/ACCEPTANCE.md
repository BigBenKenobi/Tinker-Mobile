# First companion milestone acceptance

Status: **IMPLEMENTATION PRESENT — ACCEPTANCE PENDING** (6 October 2026).

Desktop source is based on Tinker main `be00c5144c104807c059b1496ae18adb749a1faf`.
The matching desktop branch adds schema 3, local domain editors, graph sync, TLS
pairing/discovery/lifecycle, ICS/recurrence and owner-based reminder deduplication.
Both repositories use `feat/iphone-companion-m1` and the same version-one contract.

| Check | Status |
|---|---|
| Original Linux desktop baseline | 86 tests passed; no skips |
| Desktop with new companion tests | 106 tests passed; no skips; isolated/offscreen |
| Desktop offscreen smoke | Recorded in matching desktop evidence |
| Swift syntax parse and Xcode OpenStep/plist structure | Passed static checks; not a build |
| Shared desktop-generated snapshot fixture | Passed in Simulator XCTest |
| Xcode build and 11 XCTest cases in Simulator | PASS: Xcode 16.4, iPhone 16 Pro/iOS 18.5; [recorded evidence](XCODE-SIMULATOR.md) |
| Native Fedora UI, firewall and Bonjour over LAN | Pending |
| Physical iPhone pairing/offline/reconnect/notifications/Files | Pending |

## Mac / Simulator gate

Automated build and 11 tests passed on the code commit recorded in [Xcode evidence](XCODE-SIMULATOR.md). Manual Simulator UI and minimum-iOS-runtime acceptance remain pending. Verify
three screens at large Dynamic Type, VoiceOver labels, search, archive/pin, task
completion, recurrence weekdays/end limits, date/timezone behavior, draft retention,
delete and conflict handling. Use two temporary desktop databases and the shared
fixture to verify snapshot application, repeated uploads and edit-during-upload.
The macOS workflow runs Simulator XCTest; a green result covers only that source.

## Native Fedora and physical iPhone gate

- Install requirements in an isolated Fedora profile. Open each domain editor and
  verify native interaction, live theme styling, linked reminders, ICS and conflicts.
- Start LAN sync on a real interface; confirm Bonjour advertisement exists only
  while Tinker/listener is open. Confirm firewall failure is visible/recoverable.
- Grant/deny local-network and camera permission; scan a current QR, reject an
  expired/consumed QR and a different certificate. Store/relaunch with Keychain.
- Create/edit/delete Notes, Tasks, Calendar and linked reminders on each platform.
  Compare IDs/children after initial and incremental sync. Exit the desktop and
  edit offline; reopen both and verify convergence plus pending-edit status.
- Interrupt upload and repeat it; edit while upload is in flight; prove no duplicate
  item, outbox loss or cursor advancement after failed storage.
- Concurrently edit and delete the same parent. Inspect both complete versions and
  resolve each direction; race resolution with another edit and inspect the new
  conflict. Verify local pending edits cannot be erased by conflict resolution.
- Check recurrence across NZ DST, month ends, leap years, COUNT/UNTIL, weekday
  intervals, cancellation and movement. Exchange Unicode/all-day/TZID/alarm ICS
  through Files in both directions. Reject unsupported rules without partial import.
- Grant/deny notification permission. Verify reminder delivery ownership and stable
  request IDs, cancellation after synced deletion/completion, recurring exceptions,
  repeated foreground refresh, device restart, and the next-60/30-day queue policy.
  Offline deletes on the other device cannot cancel unsynced scheduled notifications.
- Background/foreground repeatedly. Test a best-effort BGAppRefresh invocation and
  expiration/cancellation; no background delivery timing guarantee is implied.
- Unpair on the phone then revoke on Fedora; confirm the old bearer fails. Inspect
  normal JSON/ICS exports to prove no identity/key/credential content is present.

Record OS/Xcode/device versions, source commits, commands/results, failures and
screenshots. Physical checks and signing/distribution are not complete merely
because Simulator CI is green. No merge, release or full acceptance is recorded.

Apple references: [background refresh](https://developer.apple.com/documentation/BackgroundTasks/refreshing-and-maintaining-your-app-using-background-tasks),
[local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app),
[local-network usage description](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSLocalNetworkUsageDescription).
