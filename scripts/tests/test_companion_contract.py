"""Reject protocol artifact and peer drift without importing private app source.

Disposable mirror copies exercise the production standard-library digest gate.
Native behavioral conformance is owned by CompanionTests in the Simulator suite.
"""

import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("contract_gate", ROOT / "scripts/check_companion_contract.py")
GATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATE)


class ContractDriftTests(unittest.TestCase):
    """Each test owns synthetic artifact copies; live manifests are never edited."""

    def setUp(self):
        """Copy local, peer and canonical boundaries for isolated failure probes."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.local, self.peer, self.canonical = (Path(self.temp.name) / name for name in ("local", "peer", "canonical"))
        for root in (self.local, self.peer, self.canonical):
            shutil.copytree(ROOT / "contracts", root / "contracts")

    def test_matching_pair(self):
        """Identical digests and canonical pin form a valid mirror pair."""
        self.assertTrue(GATE.verify(self.local, self.canonical, self.peer))

    def test_contract_drift(self):
        """Even a whitespace edit fails the pinned contract byte gate."""
        path = self.local / "contracts/SYNC-v2.md"
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaises(ValueError): GATE.verify(self.local)

    def test_fixture_drift(self):
        """Changed synthetic fixture bytes cannot silently bypass their pin."""
        path = self.local / "contracts/conformance-v2.json"
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaises(ValueError): GATE.verify(self.local)

    def test_peer_pin_drift(self):
        """Equal bytes pinned to a different source need a paired update review."""
        path = self.peer / "contracts/compatibility-v2.json"
        manifest = json.loads(path.read_text()); manifest["canonical_sha"] = "0" * 40
        path.write_text(json.dumps(manifest))
        with self.assertRaises(ValueError): GATE.verify(self.local, self.canonical, self.peer)

    def test_canonical_mismatch(self):
        """A local digest match still fails when the canonical bytes disagree."""
        path = self.canonical / "contracts/SYNC-v2.md"
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaises(ValueError): GATE.verify(self.local, self.canonical)

    def test_checkout_pin_mismatch(self):
        """A workflow's selected immutable checkout must match its manifest pin."""
        with self.assertRaises(ValueError): GATE.verify(self.local, self.canonical, canonical_sha="0" * 40)
