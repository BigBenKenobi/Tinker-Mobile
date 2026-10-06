#!/usr/bin/env python3
"""Parse all Swift sources with tree-sitter, reporting grammar errors only.

This Linux check catches malformed source after refactoring. It cannot check
Swift types, Apple APIs, linking, app behavior, Simulator or device acceptance.
Install tree-sitter==0.26.0 and tree-sitter-swift==0.7.4 into a tools environment.
"""
from pathlib import Path
import sys
import tree_sitter
import tree_sitter_swift


def main():
    """Visit every source, report exact parser positions, and fail on any error."""
    root = Path(__file__).resolve().parents[1]
    parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
    failures = []
    files = sorted((root / "ios").rglob("*.swift"))
    for path in files:
        source = path.read_bytes()
        tree = parser.parse(source)
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == "ERROR" or node.is_missing:
                failures.append(f"{path.relative_to(root)}:{node.start_point.row + 1}:{node.start_point.column + 1}: Swift grammar error")
            stack.extend(node.children)
    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"Parsed {len(files)} Swift files; {len(failures)} grammar errors. This is not an iOS build.")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
