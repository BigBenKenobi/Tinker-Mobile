# Development

Read AGENTS.md and docs/STATUS.md first. The app is native SwiftUI, iOS 17+, with
SQLite as durable state and Keychain as the only bearer store. Keep changes small
and include ownership/failure/data-flow comments at substantive boundaries.

Run `make project`, then `make check`. For Linux syntax checks, install the pinned
`scripts/requirements-tools.txt` in an isolated environment and run `make syntax`.
On macOS, run `make test PHONE='iPhone SE (3rd generation)'` and repeat on the large
phone. Syntax checks are not type checks or native acceptance.

Use four-space indentation, one substantive statement per line in new code, and
short methods around transaction/network boundaries. Avoid unrelated formatting
or folder churn in correctness fixes. Regenerate the Xcode project after file moves.

PRs run native regressions and navigation smoke. UI-impacting diffs also run the
full screenshot suite; manual dispatch can request full capture and an unsigned
IPA independently. Required check names remain `simulator (small)` and
`simulator (large)`. Once the baseline is accepted, require both on main, block
force pushes/deletion, and allow a solo-maintainer PR approval policy. Do not impose
a required second reviewer on a repository with only one active maintainer.

Use docs/PHYSICAL-ACCEPTANCE.md before baseline consolidation. Folder splitting,
recurrence fast-forwarding and off-main-actor storage are separate measured work;
they must not change IDs, ownership, conflict retention or sync ordering.
