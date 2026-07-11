#!/usr/bin/env python3
"""Remove a JSON path only when its value still equals the installed value."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: json_remove.py FILE DOT_PATH EXPECTED_JSON")
    path = Path(sys.argv[1])
    if not path.exists():
        return
    data = json.loads(path.read_text())
    keys = sys.argv[2].split(".")
    parent = data
    for key in keys[:-1]:
        if not isinstance(parent, dict) or key not in parent:
            return
        parent = parent[key]
    key = keys[-1]
    expected = json.loads(sys.argv[3])
    if isinstance(parent, dict) and parent.get(key) == expected:
        del parent[key]
        path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
