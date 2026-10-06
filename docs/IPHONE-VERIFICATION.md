# Full-interface verification

Status: implementation present; native and visual acceptance pending.
Source: feat/iphone-full-interface, based on mobile
12e12e1413e838bb254953b1d7dca9334ffa3e30 and desktop reference
b49b68bc6e4da6b3b5f0a3fc5c42b2c75435c39a.

| Check | Current result |
|---|---|
| Generator tests | 3 passed: nested sources/assets/v2 fixture, deterministic references, enabled unit/UI scheme |
| Swift tree-sitter grammar | 31 sources, zero grammar errors; no type/API/link validation |
| Desktop theme reference | 8 tests passed |
| Desktop companion/recurrence/ICS reference | 10 tests passed |
| Native unit tests | 24 passed on each Simulator in run 37457168704 (SHA 3d2a2af) |
| Xcode build / UI regression | Xcode 16.4 builds on small and large iPhone Simulators; 2 of 4 UI tests failed per target in run 37457168704; fixes and diagnostic collection running |
| Final unsigned IPA | Not built |
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
Run 37457168704 executed 28 tests per device: 26 passed, 2 failed, zero
skipped or expected failures. This is diagnosed intermediate evidence, not
full UI acceptance. GitHub API and artifact download access now work.

Run .github/workflows/ios.yml on this branch or run the shared scheme on a Mac.
Both small and large Simulator jobs must pass before native readiness is claimed.
Review screenshots and fix failures before acceptance. Build the unsigned IPA
from the same final tested commit; a Simulator pass is not an IPA.

One final phone session remains: install over existing data, retain pairing,
offline/reconnect sync, notifications, Files, VoiceOver, visual feel and battery.
Keep the review branch unmerged.
