#!/usr/bin/env python3
"""Expose Xcode errors as check annotations without changing the build result.

GitHub log/artifact downloads use a separate host that may be blocked in cloud
environments. Annotations make concrete compiler/test failures available through
the standard checks API. The calling workflow preserves xcodebuild's exit status.
"""
import re
import sys
from pathlib import Path


def escape(value):
    """Encode annotation control characters so compiler text stays ordinary data."""
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main():
    """Read a current build log and emit file diagnostics or generic test errors."""
    root = Path.cwd()
    for line in Path(sys.argv[1]).read_text(errors="replace").splitlines():
        match = re.search(r"^(.+\.swift):(\d+)(?::\d+)?: error: (.+)", line)
        if match:
            path, number, message = match.groups()
            try:
                path = str(Path(path).relative_to(root))
            except ValueError:
                pass
            # File properties also encode commas/colons per Actions syntax.
            safe_path = escape(path).replace(",", "%2C").replace(":", "%3A")
            print(f"::error file={safe_path},line={number}::{escape(message)}")
        elif "error:" in line or (line.startswith("Test Case") and " failed " in line):
            print("::error::" + escape(line))


if __name__ == "__main__":
    main()
