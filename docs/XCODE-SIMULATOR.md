# Xcode Simulator verification — 6 October 2026

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
