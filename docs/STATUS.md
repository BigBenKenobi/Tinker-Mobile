# Current acceptance status

This is the entry point for current validation. Older narrative results in
`ACCEPTANCE.md`, `IPHONE-VERIFICATION.md`, `static-checks.json`, and PR descriptions
are historical evidence for their named commits, not the current build.

The data-safety changes enter the companion branch first and are carried into
full-interface and minimal-home descendants without merging either application PR.

| Review branch | Purpose | Acceptance |
|---|---|---|
| `feat/iphone-companion-m1` / PR #1 | Native companion plus safe local saves and reviewed ICS imports | 28/28 native tests per phone passed; physical approval pending |
| `feat/iphone-full-interface` / draft PR #2 | Interface with the same data-safety fixes | 43/43 native tests per phone passed; physical approval pending |
| `ui/minimal-chat-sync-status` | Integrated minimal home, recovery/build identity and measured quiet-work changes | 47/47 native tests per phone and unsigned build passed; physical session pending |
| `main` | Repository entry point | Application baseline not accepted yet |

## Current candidate

**Build 59**, source `db007a3390c8a2ff25e511f615d4e5ff0b8f713c`:
[native regressions](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37647511855)
and [unsigned device build](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37647505368)
pass. Each phone ran 45 unit tests and two UI smoke cases, with zero failures,
skips or expected failures. The IPA payload, bundle ID, arm64 executable and
embedded source/build were independently checked after download. This candidate
supersedes the intermediate build 55; physical acceptance is still pending.

[Measured workloads](MEASUREMENTS.md) and the [prepared main protection payload](maintenance/main-protection.json)
are separate from physical acceptance. The shared contract's opening schema-four
wording describes its origin; its detailed schema-five definition and current
fixture govern protocol 2. Contract bytes remain aligned with the desktop.

## Authoritative build evidence

Each new native CI job writes a `validation-<phone>` or
`validation-unsigned-device` artifact, retained for 90 days. The JSON records the
actual checked-out source SHA, build-input digest, run/attempt, toolchain, protocol
2/schema 5, contract/fixture digests, actual XCTest summary or IPA payload digest.
Full result bundles/screenshots and unsigned IPA files remain for 14 days.

Use [current workflow runs](https://github.com/BigBenKenobi/Tinker-Mobile/actions/workflows/ios.yml)
and the candidate record in [validation/current.json](validation/current.json).
A later documentation-only commit may point to an earlier tested build; compare
`build_inputs_sha256` before treating that result as applicable. Never copy a test
count into a document as evidence of a fresh run.

Screenshots exported by CI remain **not visually reviewed** until inspection is
recorded. Unsigned device builds remain **not physically accepted** until the
[physical checklist](PHYSICAL-ACCEPTANCE.md) is completed for that build.

## Fix behavior

- Editor opening tokens include desktop revision and durable local operation ID.
  Stale saves/deletes fail without changing the graph or outbox, and editors stay
  open with their draft. Local tokens never enter protocol JSON; no database
  migration or new sync field is required.
- ICS import requires a chosen calendar and explicit per-event replacement preview.
  Matched events keep calendar membership, matching child identities and reminder
  delivery ownership. Pending edits/conflicts and unsynced event deletions block
  import. Changes after preview require another review. The whole file commits
  atomically. Negative relative alarms support one second through 366 days;
  malformed and overflowing durations fail before any storage writes.
- Empty pull pages validate identity/cursor without refreshing all records.
  Unchanged pairing avoids a Keychain write; notification reconciliation compares
  actual OS requests and renews its planning horizon at least once a minute.
  Calendar projection caching retains the existing recurrence algorithm.
- Recovery uses a consistent SQLite backup from a running store, or copies the
  rejected closed database and all surviving sidecars after startup failure.
  Credentials stay in Keychain. See [recovery](RECOVERY.md).

## Remaining gates

Physical upgrade/pairing retention, current-build Files/conflict/reminder behavior,
VoiceOver, layout and battery require the owner and a phone. Minimum iOS 17 runtime
coverage is separate from routine iOS 18.5 CI. Broader recurrence optimization and
moving storage off MainActor require device profiles; no speed or battery claim is
made solely from Simulator timing. Repository licensing is an owner decision.


## Step 12 compatibility review

The corrective Step 12 draft adds pinned public contract/schema digests and the
shared 18-case synthetic corpus, plus three native XCTest cases for graph
validation, offline conflict/deletion acknowledgement and all-day DST projection.
Graph decoding rejects missing/unknown fields, incorrect scalar types, duplicate
children and foreign linked-record ownership before projection. No protocol or
local schema version changes. See ../contracts/COMPATIBILITY.md and
validation/2026-10-08-protocol-compatibility.json for paired source/build identity.

Nine local Python gate/project tests pass; 37 Swift sources parse without grammar
errors. New XCTest compilation/execution is pending a Mac/Simulator result.
Historical build 59/source db007a3 remains the installed candidate; this review
does not identify a newly built or physically accepted phone app. Desktop hosted
checks remain subject to the account billing/spending gate. Keep drafts unmerged.
