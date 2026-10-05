# Build and keep Tinker on one iPhone

## What lives where

Tinker Desktop holds the primary schema-five Notes, Tasks, and Calendar database and runs the local sync listener only while the desktop app is open. The iPhone holds its own offline SQLite data and Keychain pairing. GitHub's ephemeral `macos-26` runner builds the unsigned iPhone IPA with Xcode 26. Fedora needs no macOS VM or Xcode installation. Keep only this source checkout, the current IPA, and SideStore's small initial setup tools on Fedora.

The first release pairs one phone on the same Wi-Fi. Protocol two deliberately rejects the earlier draft phone build. The iPhone deployment target remains iOS 17. The bundle identity is `com.bigbenkenobi.tinker-companion`; keep that identity unchanged for updates that retain local app data.

## Build the IPA after code changes

1. Open **Actions → iPhone companion → Run workflow** in the Tinker-Mobile GitHub repository. Choose the branch containing the matching protocol-two phone code. The Simulator job and the manual `unsigned-device-ipa` job will run. The device job verifies Xcode 26 and the bundle ID, builds for `generic/platform=iOS` with signing disabled, and uploads `TinkerCompanion-unsigned-device-ipa` for three days.
2. Download the artifact zip to Fedora and extract `TinkerCompanion-unsigned.ipa`. Do not upload an Apple Account, certificate, or provisioning profile to CI. GitHub Actions use for a private repository depends on its current allowance.
3. Reuse the installed IPA for weekly signing refresh. Run this workflow again only after Tinker's code changes.

[GitHub's macOS 26 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md) currently includes Xcode 26. The workflow checks the major version rather than silently building with a later Xcode.

## One-time Fedora and SideStore setup

1. On the iPhone, connect to Wi-Fi, enable a passcode, install **LocalDevVPN**, and turn it on. On Fedora, install `usbmuxd` from the Fedora package manager and download the Fedora RPM or AppImage of **iloader**. Use a USB cable for this initial pairing and trust the computer when iOS asks. [SideStore's Linux prerequisites](https://docs.sidestore.io/docs/installation/prerequisites) list the current packages and download choices.
2. Follow [SideStore's installation steps](https://docs.sidestore.io/docs/installation/install) with iloader and the same Apple Account you will use in SideStore. Trust the developer app in iOS Settings and enable Developer Mode. Open SideStore and refresh **SideStore itself first** before installing Tinker. For iOS 26.4 or newer, switch to the [SideStore nightly](https://docs.sidestore.io/docs/troubleshooting/error-codes) as directed by its troubleshooting guide: in SideStore Settings, enable beta updates, select **nightly**, and install the offered update. Its [FAQ](https://docs.sidestore.io/docs/faq) also permits sideloading the nightly IPA through SideStore or iloader.
3. Send the downloaded IPA to the iPhone with Files/AirDrop or another normal file transfer, then import it into SideStore. SideStore signs it on the phone; confirm Tinker appears under **My Apps**. SideStore and Tinker use two of the free account's three app slots.
4. Open Desktop Tinker → **iPhone Sync**, enter Fedora's current Wi-Fi IPv4 address, start local sync, and show the two-minute QR. On the iPhone, open Companion → scan the QR. The two apps should show connected status while both are open on the same network.

## Real-device acceptance

Complete this before relying on weekly use:

- Install Tinker from the unsigned IPA and pair it with Fedora.
- On each device, change a note, independent task, note reminder, calendar/event, and an event exception while the other device is offline. Reconnect and inspect both sides. Confirm that deleting an item produces a deletion on the other side and that concurrent edits remain visible as a conflict until resolved.
- Set a phone-owned reminder and receive its local notification. Desktop-owned reminders should appear on Fedora alone.
- With Wi-Fi and LocalDevVPN on, manually refresh **SideStore and Tinker** in SideStore. Open Tinker afterward and verify its local edits and pairing are still present.
- When installing a newer IPA, install it as an update with the same bundle identity and verify the offline data remains. Do not remove Tinker first.

## Five-day routine

Create a repeating reminder on the iPhone for about **day five after the initial install**. Each time it fires: connect to Wi-Fi, enable LocalDevVPN, open SideStore → My Apps, manually refresh **SideStore and Tinker**, then launch Tinker and confirm both the app and its local data open. Background refresh is a bonus, not the schedule. Apple's [Personal Team documentation](https://developer.apple.com/help/account/basics/about-your-developer-account) says free provisioning profiles expire seven days after issuance. [SideStore's prerequisites](https://docs.sidestore.io/docs/installation/prerequisites) require Wi-Fi and LocalDevVPN for installing, updating, and refreshing.

If SideStore cannot see the phone after an iOS update, use iloader to renew the pairing file as described in its installation guide. The one-time Fedora tools remain useful for that recovery.
