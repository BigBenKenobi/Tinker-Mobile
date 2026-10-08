#!/usr/bin/env python3
"""Record the checked-out source and actual native outputs for one CI job.

This manifest accompanies artifacts for 90 days. It never marks screenshots as
visually reviewed or an unsigned device build as physical acceptance. A digest of
build inputs allows later documentation-only commits to reference this evidence.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess


def command(*args):
    """Return required provenance; command failure fails manifest generation."""
    return subprocess.check_output(args, text=True).strip()


def input_digest():
    """Hash tracked build inputs in stable path order, excluding narrative docs."""
    digest = hashlib.sha256()
    files = command('git', 'ls-files').splitlines()
    for name in sorted(files):
        if name.startswith(('ios/', 'contracts/', 'scripts/', '.github/workflows/')):
            digest.update(name.encode() + b'\0' + Path(name).read_bytes() + b'\0')
    return digest.hexdigest()


def main():
    """Combine exact Git/toolchain identity with xcresult data or payload digest."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--kind', choices=['simulator', 'unsigned-device'], required=True)
    parser.add_argument('--summary', type=Path)
    parser.add_argument('--payload', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    evidence = {
        'format_version': 1,
        'source_sha': command('git', 'rev-parse', 'HEAD'),
        'build_inputs_sha256': input_digest(),
        'protocol_version': 2,
        'desktop_schema_version': 5,
        'mobile_schema_version': 2,
        'canonical_contract_sha': json.loads(Path('contracts/compatibility-v2.json').read_text())['canonical_sha'],
        'kind': args.kind,
        'run_id': os.environ.get('GITHUB_RUN_ID'),
        'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
        'build_number': os.environ.get('GITHUB_RUN_NUMBER'),
        'toolchain': command('xcodebuild', '-version'),
        'host': platform.platform(),
        'full_capture_requested': os.environ.get('FULL_CAPTURE') == 'true',
        'visual_review': 'pending',
        'physical_acceptance': 'pending',
        'contract_sha256': hashlib.sha256(Path('contracts/SYNC-v2.md').read_bytes()).hexdigest(),
        'fixture_sha256': hashlib.sha256(Path('contracts/snapshot-v2.json').read_bytes()).hexdigest(),
        'conformance_fixture_sha256': hashlib.sha256(Path('contracts/conformance-v2.json').read_bytes()).hexdigest(),
    }
    if args.summary and args.summary.exists():
        evidence['xctest'] = json.loads(args.summary.read_text())
    if args.payload:
        evidence['payload_sha256'] = hashlib.sha256(args.payload.read_bytes()).hexdigest()
        evidence['payload_bytes'] = args.payload.stat().st_size
    args.output.write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
