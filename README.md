# Tinker for iPhone

Native SwiftUI iPhone companion for Tinker on Fedora: offline Notes, Tasks and
Calendar in SQLite, with paired HTTPS synchronization on the same local network.
Requires iOS 17 or later. The application is under review and has not yet been
accepted into the default branch.

## Active review stack

1. [PR #1 — companion baseline](https://github.com/BigBenKenobi/Tinker-Mobile/pull/1),
   branch `feat/iphone-companion-m1`, includes local-save and ICS data-safety fixes.
2. [Draft PR #2 — full interface](https://github.com/BigBenKenobi/Tinker-Mobile/pull/2),
   branch `feat/iphone-full-interface`, depends on the companion baseline.
3. [Draft PR #3 — integrated acceptance candidate](https://github.com/BigBenKenobi/Tinker-Mobile/pull/3),
   branch `ui/minimal-chat-sync-status`, includes the minimal Home, recovery exports,
   build identification, durable validation evidence and quiet-work improvements.

To inspect/build the integrated candidate, clone this repository and check out
`ui/minimal-chat-sync-status`. Follow its
[build guide](https://github.com/BigBenKenobi/Tinker-Mobile/blob/ui/minimal-chat-sync-status/README.md),
[current status](https://github.com/BigBenKenobi/Tinker-Mobile/blob/ui/minimal-chat-sync-status/docs/STATUS.md),
and [physical acceptance checklist](https://github.com/BigBenKenobi/Tinker-Mobile/blob/ui/minimal-chat-sync-status/docs/PHYSICAL-ACCEPTANCE.md).
The matching desktop dependency is [Tinker PR #11](https://github.com/BigBenKenobi/Tinker/pull/11).

CI results apply to their exact source commits. An unsigned IPA, screenshot export
or Simulator pass does not establish physical acceptance. Application branches
remain unmerged until acceptance is approved. Preserve their ancestry through
normal merge commits, update dependent review bases, and validate each proposed
merge before retiring branches. The default branch will contain the application
after that process; this README makes the current state explicit in the meantime.
