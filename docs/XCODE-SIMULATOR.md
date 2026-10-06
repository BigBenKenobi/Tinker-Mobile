# Xcode Simulator verification

## Companion baseline release gate — 7 October 2026

This evidence covers the companion-only source revision below. The combined
`feat/iphone-full-interface` branch needs a fresh Simulator and IPA release
gate before it can be treated as current release evidence.

Tested mobile code commit: `51474b7bb51ecfe34c86a506e15dfe4775c92d3c`.

[Successful release-gate run](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37539495753)
(run ID `37539495753`). The generated-project consistency check passed. The
Simulator job used macOS 15.7.9, Xcode 16.4 (16F6), and an iPhone 16 Pro
Simulator on iOS 18.5; all 16 XCTest cases passed with zero failures. The
unsigned-device job used macOS 26.6.2 and Xcode 26.6 (17F113), built the Release
app for generic iPhone hardware, confirmed the bundle identifier
`com.bigbenkenobi.tinker-companion`, and rejected any code signature before
packaging.

Downloaded artifact:
`dist/TinkerCompanion-unsigned-51474b7-run-37539495753.ipa`

- Size: 490,134 bytes
- SHA-256: `5c359e4f1ea3fb878cd82f764097d6ece021897da9e6f82eabd21ded38c18544`
- Local verification: ZIP integrity passed, bundle identifier matched, and no
  `_CodeSignature` directory was present.

The first run of this release gate exposed a Swift definite-initialization error
in event-exception projection. Commit `51474b7bb51ecfe34c86a506e15dfe4775c92d3c`
contains the focused correction and is the only source revision represented by
the successful evidence above. Later evidence-only commits do not change the
tested Swift sources or generated project. Physical iPhone installation,
networking, permissions, notifications, and manual UI acceptance remain pending.

Relevant runner log excerpt:

```text
2026-10-06T22:16:22Z macOS 15.7.9; runner image macos-15-arm64
2026-10-06T22:16:24Z macOS 26.6.2; runner image macos-26-arm64
2026-10-06T22:16:24Z Xcode 16.4; Build version 16F6
2026-10-06T22:16:28Z Xcode 26.6; Build version 17F113
2026-10-06T22:16:48Z iPhone 16 Pro Simulator; iOS 18.5
2026-10-06T22:18:35Z Executed 16 tests, with 0 failures (0 unexpected)
2026-10-06T22:18:36Z TEST SUCCEEDED
```

## Previous baseline — 6 October 2026

Tested mobile code commit: `f84d5c02f3f9017e5f506a47a45c871a25ffff83`.

[Successful macOS CI run](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37366091499).
macOS 15.7.9, Xcode 16.4 (16F6), iPhone 16 Pro Simulator on iOS 18.5.
The native app and XCTest bundle built; all 11 tests passed, zero failures.
Tests include offline persistence/reopen, snapshot versus pending edits,
edit-during-upload acknowledgement, tombstones, conflict preservation/resolution,
atomic import, validation, recurrence/DST/month ends, ICS exchange, pairing endpoint
validation and the desktop-generated shared snapshot. This records automated
Simulator tests, not physical networking/permissions/notifications or manual UI
acceptance. iOS 17 is the deployment target; an iOS 17 runtime was not tested.

The earlier run caught a result-returning SQLite pragma initialization bug; it was
corrected before this successful final code run. Later evidence-only commits do
not change the tested Swift sources or project.

Relevant runner log excerpt:

```text
2026-10-05T19:52:25.0230840Z macOS
2026-10-05T19:52:25.0231120Z 15.7.9
2026-10-05T19:52:26.9386660Z Xcode 16.4
2026-10-05T19:52:26.9393810Z Build version 16F6
2026-10-05T19:52:32.3552680Z { platform:iOS Simulator, arch:arm64, id:DC4CD8B3-4457-4153-9087-A0D7A2F9BFD9, OS:18.5, name:iPhone 16 Pro }
2026-10-05T19:53:25.4400050Z Test Case '-[TinkerCompanionTests.CompanionTests testAcknowledgementPreservesEditMadeDuringUpload]' passed (0.016 seconds).
2026-10-05T19:53:25.4716630Z Test Case '-[TinkerCompanionTests.CompanionTests testConflictKeepsBothVersionsAndResolutionUsesInspectedRevision]' passed (0.009 seconds).
2026-10-05T19:53:25.4959430Z Test Case '-[TinkerCompanionTests.CompanionTests testDeletionIsAnOfflineTombstone]' passed (0.006 seconds).
2026-10-05T19:53:25.5560700Z Test Case '-[TinkerCompanionTests.CompanionTests testICSUnicodeRecurrenceAndExceptionsRoundtrip]' passed (0.009 seconds).
2026-10-05T19:53:25.5777150Z Test Case '-[TinkerCompanionTests.CompanionTests testInvalidImportIsAtomic]' passed (0.116 seconds).
2026-10-05T19:53:25.5879140Z Test Case '-[TinkerCompanionTests.CompanionTests testOfflineEditsAndStableIDsSurviveReopen]' passed (0.008 seconds).
2026-10-05T19:53:25.6091530Z Test Case '-[TinkerCompanionTests.CompanionTests testPublicEndpointsAndExpiredQRFailBeforeNetwork]' passed (0.001 seconds).
2026-10-05T19:53:25.6296520Z Test Case '-[TinkerCompanionTests.CompanionTests testRecurrenceAcrossDSTAndMonthEnd]' passed (0.002 seconds).
2026-10-05T19:53:25.6551410Z Test Case '-[TinkerCompanionTests.CompanionTests testSharedDesktopSnapshotFixture]' passed (0.012 seconds).
2026-10-05T19:53:25.6779380Z Test Case '-[TinkerCompanionTests.CompanionTests testSnapshotCannotErasePendingOfflineEdit]' passed (0.006 seconds).
2026-10-05T19:53:25.7063160Z Test Case '-[TinkerCompanionTests.CompanionTests testStrictSharedFieldsAndCredentialMetadata]' passed (0.001 seconds).
2026-10-05T19:53:25.7363380Z 	 Executed 11 tests, with 0 failures (0 unexpected) in 0.186 (0.250) seconds
2026-10-05T19:53:25.7585600Z 	 Executed 11 tests, with 0 failures (0 unexpected) in 0.186 (0.250) seconds
2026-10-05T19:53:25.7742530Z Test Suite 'All tests' passed at 2026-10-05 19:53:25.030.
2026-10-05T19:53:25.7846420Z 	 Executed 11 tests, with 0 failures (0 unexpected) in 0.186 (0.250) seconds
2026-10-05T19:53:26.0083530Z ** TEST SUCCEEDED **
```
