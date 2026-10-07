> Historical implementation/validation narrative. For current source, results and
> remaining gates, see [STATUS.md](STATUS.md). Statements below apply to their
> original recorded commits and have not been promoted to fresh acceptance.

# Full-interface verification

Status: integrated native build and automated regression pass on both phone sizes.
Original-reference comparison and physical-device acceptance remain pending.
The final run, screenshot review and exact IPA source are recorded in
[draft PR 2](https://github.com/BigBenKenobi/Tinker-Mobile/pull/2).
Source: feat/iphone-full-interface, based on mobile
12e12e1413e838bb254953b1d7dca9334ffa3e30 and desktop reference
b49b68bc6e4da6b3b5f0a3fc5c42b2c75435c39a.

| Check | Current result |
|---|---|
| Generator tests | 3 passed: nested sources/assets/v2 fixture, deterministic references, enabled unit/UI scheme |
| Swift tree-sitter grammar | 31 sources, zero grammar errors; no type/API/link validation |
| Desktop theme reference | 8 tests passed |
| Desktop companion/recurrence/ICS reference | 10 tests passed |
| Native unit tests | 27 passed per device in run 37549336544 (SHA 78ae01c) |
| Xcode build / UI regression | Xcode 16.4 / iOS 18.5; 4 UI tests passed per device in run 37549336544; 39 screenshots per device |
| Unsigned device IPA | Xcode 26.6 build passed in run 37549336544; ZIP CRC, arm64 binary, bundle ID, minimum iOS and absent code signature verified |
| Original screenshot parity | Reference media absent from desktop checkout |
| Physical iPhone acceptance | Pending |

Commands executed from their respective repositories:

- Mobile: python3 -m unittest discover -s scripts/tests -v
- Mobile: /workspace/.tinker-desktop-venv/bin/python scripts/check_swift_syntax.py
- Desktop: PYTHONDONTWRITEBYTECODE=1 /workspace/.tinker-desktop-venv/bin/python -m unittest tests.test_theme_logic -v
- Desktop: PYTHONDONTWRITEBYTECODE=1 /workspace/.tinker-desktop-venv/bin/python -m pytest -p no:cacheprovider tests/test_companion.py tests/test_calendar_recurrence_port.py tests/test_calendar_ics_port.py -q

Initial desktop checks required installing documented requirements and pytest
in a tools venv outside the reference checkout. Reference files remain clean.
New iOS tests cover phone-only persistence, duplicate/malformed imports, palette
round trips/defaults/contrast, isolated sync, NZ DST and task projections.
Existing native regressions remain in the scheme. UI tests add retained/restart
draft checks, fixture launches and screenshots. Native builds and unit tests have executed on GitHub macOS runners.
Run 37549336544 executed 31 tests per device: 31 passed, zero failed,
skipped or expected failures. The scheme includes 27 unit regressions and four
UI cases. GitHub API and artifact download access work. Calendar rotation
originally failed in UIKit's self-sizing collection layout; moving the calendar
grid to a scrollable panel stack resolved the native crash. Drawer tests require
fully visible targets, including at accessibility XXXL.

This passing run produced 39 attachments per device. Application-bound
landscape screenshots had incorrect cropping; the final capture suite uses
full-device screenshots. The final source, artifacts and visual review are
recorded in PR 2 so the release evidence remains tied to an actual run.

Run .github/workflows/ios.yml on this branch or run the shared scheme on a Mac.
Both small and large Simulator jobs must pass before native readiness is claimed.
Review screenshots and fix failures before acceptance. Build the unsigned IPA
from the same final tested commit; a Simulator pass is not an IPA.

One final phone session remains: install over existing data, retain pairing,
offline/reconnect sync, notifications, Files, VoiceOver, visual feel and battery.
Keep the review branch unmerged.
