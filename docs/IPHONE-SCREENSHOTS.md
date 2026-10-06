# Screenshot index

Status: intermediate screenshot evidence downloaded and inspected from run
37457168704, SHA 3d2a2af, Xcode 16.4 / iPhone 16 Pro Max.
Portrait forest/monospace styling is present. Landscape captures include
incomplete layout and a startup error; the set is not accepted.
Final complete small/large captures remain pending.
The UI target emits persistent XCTest attachments inside the workflow's
xcode-results-small and xcode-results-large artifacts.

| Test | Expected attachment naming | Intended coverage | Evidence |
|---|---|---|---|
| testDestinationScreenshots | Destination-[route]-portrait/landscape | All 18 destinations, two orientations | Intermediate / incomplete |
| testComposerSurvivesNavigation | Home-retained-draft | Temporary draft retention | Intermediate / incomplete |
| testPopulatedAndErrorFixturesWithLargeText | populated/error-Notes-accessibility-XXXL | Labelled fixtures, large text | Intermediate / incomplete |

After CI: download actual result bundles, inspect attachments, record the tested
SHA and device/runtime, add artifact links and compare with original references.
Themes, sheets, keyboard transitions, VoiceOver, Reduce Motion, Low Power Mode
and battery behavior require additional native checks. This index does not
claim that the screenshot tests provide complete visual acceptance.
