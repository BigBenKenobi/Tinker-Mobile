# Screenshot index

Status: no screenshots from this branch have been produced or reviewed.
The UI target emits persistent XCTest attachments inside the workflow's
xcode-results-small and xcode-results-large artifacts.

| Test | Expected attachment naming | Intended coverage | Evidence |
|---|---|---|---|
| testDestinationScreenshots | Destination-[route]-portrait/landscape | All 18 destinations, two orientations | Pending Mac run |
| testComposerSurvivesNavigation | Home-retained-draft | Temporary draft retention | Pending Mac run |
| testPopulatedAndErrorFixturesWithLargeText | populated/error-Notes-accessibility-XXXL | Labelled fixtures, large text | Pending Mac run |

After CI: download actual result bundles, inspect attachments, record the tested
SHA and device/runtime, add artifact links and compare with original references.
Themes, sheets, keyboard transitions, VoiceOver, Reduce Motion, Low Power Mode
and battery behavior require additional native checks. This index does not
claim that the screenshot tests provide complete visual acceptance.
