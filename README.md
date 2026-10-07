# Tinker for iPhone

Current review stack and acceptance gates: [status record](https://github.com/BigBenKenobi/Tinker-Mobile/blob/ui/minimal-chat-sync-status/docs/STATUS.md). Application PRs remain unmerged pending acceptance.

Native SwiftUI iPhone companion, iOS 17+. Notes, Tasks and Calendar use an on-device
SQLite store and durable offline edits. Sync is local-network only, with the
Fedora desktop app open. No hosted runtime, account or model service is used.

## Full iPhone interface review

The feat/iphone-full-interface branch adds the desktop-aligned shell, dedicated
visual workspaces, phone-only appearance persistence, all 16 palettes, Files
theme exchange and bounded backgrounds. Unsupported services are visibly
disabled; temporary drafts never become simulated sends or durable records.

See [coverage](docs/IPHONE-COVERAGE.md) and [verification](docs/IPHONE-VERIFICATION.md).
This is an implementation review, not native or physical-device acceptance.

## Build and run

Open `ios/TinkerCompanion.xcodeproj` on a Mac with Xcode supporting iOS 17+, select
the `TinkerCompanion` scheme and an iPhone Simulator, then Run or Test. The project
is checked in and requires no XcodeGen or third-party iOS packages. For a physical
iPhone, choose your signing team and device in Xcode. A personal development install
uses Apple's signing rules; no App Store release is part of this milestone.

```sh
xcodebuild -project ios/TinkerCompanion.xcodeproj \
  -scheme TinkerCompanion \
  -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO test
```

Regenerate file references after adding Swift files with
`python3 scripts/generate_xcode_project.py`. The repository includes a macOS
Simulator CI workflow; its result is separate from physical-device acceptance.

## Pair with Fedora

1. Use Tinker's matching `feat/iphone-companion-m1` desktop branch and install its
   requirements (`python3 -m pip install -r requirements.txt` in a virtual environment).
2. Open **iPhone Companion**, enter the Fedora LAN IPv4 address, and start local
   sync. The selected address is remembered and restarted while Tinker is open.
   Allow the displayed TCP port in your Fedora LAN firewall if necessary; no
   public forwarding or remote tunnel is used. The port may change on restart;
   Bonjour discovery updates the phone's address while retaining certificate trust.
3. Show the two-minute pairing QR. On the phone open **Companion → Scan desktop
   pairing QR** and grant camera/local-network access. Grant notifications separately.
4. Create/edit/delete items offline. Open/foreground the phone on the same Wi-Fi
   to sync; it checks again every 15 seconds while active. Inspect pending edits and
   conflicts in Companion. Background refresh is best effort.

Unpair on the old phone before revoking/replacing it in Fedora; this cancels its
pending notifications. Local items and offline edits are retained after unpair.
The first milestone supports one paired phone and one desktop identity per store.
A changed certificate or another desktop is rejected; recovering a restored store
or changing desktops requires an explicit migration/recovery workflow, not an
automatic destructive reset.

## Scope and acceptance

Notes: create/edit/delete, search, pinned/archive state, linked reminders.
Tasks: create/edit/delete, search, status/completion, due dates, linked reminders.
Calendar: native date selection, day agenda, search, create/edit/delete, supported
recurrence and per-occurrence changes, linked reminders, Files ICS import/export.
Conflicts preserve complete versions and require an explicit choice.

The recurrence/ICS subset and reminder budgets are documented in
[the shared sync contract](contracts/SYNC-v1.md). Full RFC5545, iPad layouts, hosted sync and remote models remain unavailable. Other workspaces provide visual
layouts and disabled operations; Chat has a temporary composer only. OS notifications cannot guarantee delivery of changes not yet synced.

See [acceptance](docs/ACCEPTANCE.md) for verified checks and pending gates. Linux
cannot compile/test UIKit, SwiftUI, Keychain, VisionKit, Bonjour permissions or
physical notifications. Do not treat syntax parsing as an iOS build.
