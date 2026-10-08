"""Check the pinned public protocol artifact without importing either app.

Both repositories run this identical standard-library gate. The local manifest
pins immutable canonical bytes; CI supplies the public checkout at that SHA.
Optional peer comparison checks the two candidate mirrors in a paired review.
Only synthetic contract artifacts are read; private desktop source is not copied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def contract_root(root: Path) -> Path:
    """Find the artifact boundary for either repository, failing if absent."""
    for relative in ("contracts", "docs/companion"):
        candidate = root / relative
        if (candidate / "compatibility-v2.json").is_file():
            return candidate
    raise ValueError("Missing protocol compatibility manifest")


def verify(root: Path, canonical: Path | None = None, peer: Path | None = None,
           canonical_sha: str | None = None) -> dict:
    """Reject byte, version, canonical-pin or peer drift; return measured digests.

    Updating a pin is an explicit paired review action, never an automatic repair.
    A canonical checkout must be the immutable SHA selected by the CI checkout.
    """
    boundary = contract_root(root)
    manifest = json.loads((boundary / "compatibility-v2.json").read_text())
    if (manifest["format_version"], manifest["protocol_version"],
            manifest["desktop_schema_version"], manifest["mobile_schema_version"]) != (1, 2, 5, 2):
        raise ValueError("Unsupported compatibility versions")
    if manifest["canonical_repository"] != "BigBenKenobi/Tinker-Mobile":
        raise ValueError("Unexpected public contract owner")
    pin = manifest["canonical_sha"]
    if len(pin) != 40 or any(c not in "0123456789abcdef" for c in pin):
        raise ValueError("Canonical source must be an immutable commit SHA")
    if canonical_sha is not None and pin != canonical_sha:
        raise ValueError("Canonical checkout pin mismatch")
    expected_files = {"SYNC-v1.md", "SYNC-v2.md", "snapshot-v2.json", "conformance-v2.json"}
    if set(manifest["sha256"]) != expected_files:
        raise ValueError("Incomplete contract artifact set")
    measured = {}
    for name, expected in manifest["sha256"].items():
        data = (boundary / name).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest != expected:
            raise ValueError("Digest drift: " + name)
        if canonical is not None and data != (canonical / "contracts" / name).read_bytes():
            raise ValueError("Canonical byte mismatch: " + name)
        measured[name] = digest
    fixture = json.loads((boundary / "conformance-v2.json").read_text())
    if (fixture["format_version"], fixture["protocol_version"],
            fixture["desktop_schema_version"], fixture["mobile_schema_version"]) != (1, 2, 5, 2):
        raise ValueError("Fixture version drift")
    if peer is not None:
        other = verify(peer, canonical=canonical, canonical_sha=canonical_sha)
        if other != {"canonical_sha": pin, "sha256": measured}:
            raise ValueError("Paired candidate pin/digest mismatch")
    return {"canonical_sha": pin, "sha256": measured}


def main() -> None:
    """Expose a nonzero CI gate; failures never rewrite pins or artifacts."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--canonical-root", type=Path)
    parser.add_argument("--canonical-sha", help="Immutable ref used by CI checkout")
    parser.add_argument("--peer-root", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.root, args.canonical_root, args.peer_root, args.canonical_sha), indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, "Companion compatibility failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
