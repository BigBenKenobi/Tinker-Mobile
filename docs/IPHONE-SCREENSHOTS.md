# Screenshot index

Native capture suite: all 18 canonical destinations on iPhone SE 3 and
16 Pro Max, portrait and landscape, plus retained Home draft and labelled
populated/error Notes at accessibility XXXL. The passing implementation run
[37459091197](https://github.com/BigBenKenobi/Tinker-Mobile/actions/runs/37459091197)
(SHA 3d3994e, Xcode 16.4 / iOS 18.5) produced 39 attachments per device.

The current UI suite captures the full device screen to avoid the incorrect
landscape rectangle transforms seen with application-bound captures.
The exact final commit, artifact links and completed visual review are recorded
in [draft PR 2](https://github.com/BigBenKenobi/Tinker-Mobile/pull/2).

| Test | Attachment naming | Coverage |
|---|---|---|
| testDestinationScreenshots | Destination-[route]-portrait/landscape | All 18 destinations, 36 images per device |
| testComposerSurvivesNavigation | Home-retained-draft | Temporary draft retention, one image |
| testPopulatedAndErrorFixturesWithLargeText | populated/error-Notes-accessibility-XXXL | Labelled fixtures, two images |

Artifacts are xcode-results-small and xcode-results-large and include exported
images, their manifest, actual XCTest counts, logs and the result bundle. Images
are isolated test fixtures with disposable stores, never production records.

Original desktop screenshot references are absent from the desktop checkout.
Simulator captures do not establish reference parity, physical installation,
Files picker behavior, VoiceOver, Low Power Mode or battery acceptance. Those
remain part of the consolidated final phone session; keep the PR unmerged.
