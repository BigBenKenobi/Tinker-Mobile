# Protocol-two compatibility ownership

The maintainer owns the canonical public artifacts in Tinker-Mobile/contracts. The desktop keeps a byte-identical mirror in docs/companion. Public artifacts contain synthetic data only; private desktop source, profiles and credentials must never be mirrored. Protocol 2 uses desktop schema 5 and independent phone schema 2. Schema four describes the origin of the desktop data model, not the current wire columns.

compatibility-v2.json pins canonical commit 182e267e08eaf8d8266696e1920afe427e27ff44 and SHA-256 digests for SYNC-v1.md (inherited semantics), SYNC-v2.md, snapshot-v2.json and conformance-v2.json. The canonical commit contains contract artifacts before the gate manifest, avoiding a self-referential SHA. The check script is identical in both repositories. Each CI job checks out the public canonical repository at an immutable SHA, then verifies its bytes, the selected SHA and the local digests. Desktop CI does not publish private source; mobile CI does not need private-repository credentials.

For local review, run `python3 scripts/check_companion_contract.py`. For paired review, pass `--peer-root /path/to/other/repository`; for an immutable canonical checkout also pass `--canonical-root /path/to/canonical --canonical-sha <40-hex-SHA>`. Byte drift, missing artifact sets, schema/version drift, different candidate pins and canonical disagreement fail with a nonzero exit. These digest gates complement behavioral tests; they cannot prove compatible runtime behavior by themselves.

To update:

1. Propose the contract and synthetic fixture change in the public mobile repository. Preserve historical evidence; decide whether the change requires a protocol-version bump and upgrade procedure.
2. Commit the canonical artifact set first. Pin that immutable commit in both manifests and all relevant desktop/Simulator/device workflow checkouts. Recompute all four digests and copy only public artifacts to the desktop mirror.
3. Extend desktop Engine/validator tests and native mobile Graph/LocalStore XCTest for the same behavior. Run malformed inputs and digest/pin corruption probes, as well as replay, conflicts, linked records and calendar semantics. Regenerate the Xcode project when resources change.
4. Record both code SHAs and verification environments separately from the currently installed mobile build/source and both local schema numbers. Execute desktop hosted gates and mobile native Simulator checks before claiming paired hosted compatibility. Record physical acceptance independently.
5. Keep the corrective PRs stacked and unmerged until review and acceptance authorize integration. Never silently accept changed hashes or relabel an old installed build as new verification.

The current shared corpus has 18 graphs: four native domains, explicit deletion, inclusive all-day/DST projection and 12 malformed shape/ownership/metadata cases. Desktop tests additionally exercise engine replay/hash rejection, conflict resolution, linked-task cascading deletion and all-day storage; native mobile tests exercise durable outbox acknowledgement replay, conflicts/resolution/deletion and calendar projection. Existing native cursor/atomicity/recurrence tests remain required. This is a finite conformance corpus, not proof for every possible input.
