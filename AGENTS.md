# Engineering rules

Keep the iPhone app native SwiftUI with iOS 17+ deployment. SQLite is the durable
source of truth; Keychain is the only bearer-credential store. No hosted account,
public endpoint, remote model, telemetry or unrelated desktop content belongs in
this milestone. Never log pairing QR text, bearer tokens or private record bodies.

Read `contracts/SYNC-v1.md`, `docs/ACCEPTANCE.md` and the desktop companion contract
before changing wire behavior. Maintain stable IDs, explicit tombstones, atomic
parent/child graphs, durable replay, conflict preservation and commit-before-cursor
advancement. Reconcile changes against the matching desktop code/fixture.

Every substantive source file needs a responsibility/boundary/data-flow header.
Document important ownership, lifecycle, failure, persistence and asynchronous
behavior. Keep UI free of SQL/network logic; preserve drafts on failed local saves.

Run XCTest in Xcode/Simulator and Linux desktop tests as appropriate. Record exact
source/results and distinguish static parsing, Simulator, native Fedora and
physical iPhone evidence. Do not claim iOS build/device acceptance without a real
Mac/Xcode/device result. Keep review branches unmerged until acceptance is approved.
