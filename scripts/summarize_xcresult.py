#!/usr/bin/env python3
"""Report native XCTest outcomes from the current Xcode result bundle.

This runner-only helper reads xcresulttool's actual summary, records a current
JSON result and emits a check annotation for API-readable evidence. Zero tests,
unexplained failures or missing result data cannot establish readiness.
"""
import json
import subprocess
import sys
from pathlib import Path


def main():
    """Require an actual nonzero XCTest run and preserve its distinct outcomes."""
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", sys.argv[1]],
        capture_output=True, text=True,
    )
    if result.returncode:
        print("::notice title=Native XCTest summary::No completed test summary was available.")
        return 1
    data = json.loads(result.stdout)
    Path(sys.argv[2]).write_text(json.dumps(data, indent=2) + "\n")
    counts = {key: data.get(key) for key in
              ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures")}
    payload = json.dumps(counts, sort_keys=True)
    print("::notice title=Native XCTest summary::" + payload.replace("%", "%25"))
    total = counts["totalTestCount"]
    if not isinstance(total, int) or total <= 0:
        print("::error::XCTest did not report an executed nonzero suite.")
        return 1
    if counts["failedTests"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
