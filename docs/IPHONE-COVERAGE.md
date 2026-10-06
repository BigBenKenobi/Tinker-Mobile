# iPhone interface coverage ledger

Desktop source: `BigBenKenobi/Tinker@b49b68bc6e4da6b3b5f0a3fc5c42b2c75435c39a`.
Mobile baseline: `12e12e1413e838bb254953b1d7dca9334ffa3e30`.

Original screenshots are absent from the desktop checkout (`README.md`, TK-00). Reference parity remains pending. Every row below maps the original desktop criterion; implementation and acceptance are separate gates.

| ID | Desktop criterion | iPhone destination | Contract | Implementation / evidence |
|---|---|---|---|---|
| 01 | Application shell | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 02 | Collapsible sidebar | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 03 | Home / empty session | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 04 | Chat composer | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 05 | Model selector | Models | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 06 | Nobody / incognito session | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 07 | Composer tool menu and attachments | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 08 | Optional composer actions | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 09 | Prompt Studio | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 10 | Sessions and message rendering | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 11 | Search | Search | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Communication.swift |
| 12 | Email | Email | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Communication.swift |
| 13 | Brain — Memories | Brain | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 14 | Brain — Skills | Brain | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 15 | Brain — Add / import / export | Brain | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 16 | Brain automation preferences | Brain | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 17 | Calendar | Calendar | Functional existing productivity; enhancements pending | First-pass implementation present; native/visual acceptance pending; Productivity/CalendarView.swift; CalendarProjection.swift |
| 18 | Model Compare | Model Compare | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 19 | Cookbook | Cookbook | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 20 | Deep Research | Deep Research | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Intelligence.swift |
| 21 | Gallery — Photos | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 22 | Gallery — Albums | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 23 | Gallery editor foundation | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 24 | Gallery editing tools | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 25 | Gallery layers and history | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 26 | Inpaint workflow | Gallery | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 27 | Library | Library | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 28 | Documents | Library | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 29 | Research Library | Library | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 30 | Notes dock | Notes | Functional existing productivity; enhancements pending | First-pass implementation present; native/visual acceptance pending; Productivity/DomainView.swift; Editors.swift |
| 31 | Tasks and local scheduler | Tasks | Functional existing productivity; enhancements pending | First-pass implementation present; native/visual acceptance pending; Productivity/DomainView.swift; Editors.swift |
| 32 | Theme presets | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 33 | Theme customization | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 34 | Colour harmony generator | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 35 | Fonts, density and frosted surfaces | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 36 | Animated backgrounds | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 37 | Theme save / share | Theme | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shared/Theme.swift; Appearance/ThemeView.swift; Shared/BackgroundView.swift |
| 38 | Peek mode | Home / shared shell | Phone adaptation; desktop-only controls disabled | Desktop-only controls represented; phone navigation adaptation; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 39 | Floating tool-window framework | Home / shared shell | Phone adaptation; desktop-only controls disabled | Desktop-only controls represented; phone navigation adaptation; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 40 | Settings — Add Models | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 41 | Settings — Added Models | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 42 | Settings — AI Defaults | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 43 | Settings — Search | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 44 | Settings — Integrations | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 45 | Settings — Email navigation | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 46 | Settings — Reminders | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 47 | Settings — Appearance | Settings | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 48 | Sensitive-span presentation | Home / shared shell | Presentation; service actions unavailable | Unavailable conversation/status empty state; no execution; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 49 | Process/status presentation | Home / shared shell | Presentation; service actions unavailable | Unavailable conversation/status empty state; no execution; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 50 | Keyboard commands and shortcut editor | Settings | Phone adaptation; desktop-only controls disabled | Desktop-only controls represented; phone navigation adaptation; Workspaces/Collections.swift; ServiceSettingsView.swift |
| 51 | Account flows | Account | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 52 | Profile / Study Mode area | Account | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Workspaces/Collections.swift |
| 53 | Shared states and feedback | Home / shared shell | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; Shell/RootView.swift; Workspaces/HomeView.swift; Workspaces/Communication.swift |
| 54 | Persistence and application data | Local Data / Companion | Presentation; service actions unavailable | First-pass implementation present; native/visual acceptance pending; LocalStore.swift; Shell/PresentationStore.swift; Companion/CompanionView.swift |
| 55 | Fedora desktop validation and release polish | Cross-app acceptance | Presentation; service actions unavailable | Gate pending: Mac CI, original references and physical acceptance; docs/IPHONE-VERIFICATION.md |
| Companion | Local sync, pairing, replay, conflicts, notifications | Companion | Preserve protocol v2 and existing behavior | Baseline Mac tests documented in `XCODE-SIMULATOR.md`; new-run verification pending |

## Batch status

- Batch 1: first-pass implementation present; generator tests pass. Native isolation/UI target await Xcode execution.
- Batches 2–5: first-pass implementation present across destinations, productivity projections, palettes/interchange and bounded effects. No native/visual acceptance claim.
- Batch 6: Mac CI access blocked (GitHub API Forbidden); no new Simulator or device evidence.
- Physical acceptance: install over existing data, pairing, offline/reconnect, notifications, Files, VoiceOver and battery remain pending.

## Adaptations and limitations

- Desktop windows, Peek, minimize/resize and shortcut editing are labelled desktop-only. Phone navigation uses destinations, sheets and a drawer.
- Model, mail, research, comparison, knowledge, Gallery, Library and account execution/storage stay disabled. Forms are temporary/layout previews.
- Home has no sent conversation. Drafts clear on process restart; destination/themes persist in phone-only SQLite state.
- All desktop effect names and palettes are ported. Phone effects use capped particles, 30 FPS and one Canvas driver. Detailed effect parity and battery behavior await acceptance.
- Every row has an implementation location; passing source grammar does not establish compilation or every desktop acceptance condition.
