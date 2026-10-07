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

After approval: validate the exact companion merge candidate, merge PR #1, update
PR #2's base and verify its remaining diff, then accept interface/minimal-home work.
Use normal merge commits for the existing stack to retain ancestry. If choosing
squash instead, rebase dependent branches and revalidate before merging. Retain
branches until all work is reachable from the accepted baseline.
