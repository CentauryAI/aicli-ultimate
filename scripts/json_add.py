#!/usr/bin/env python3
"""Add a JSON path without replacing an existing value."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in {4, 5}:
        raise SystemExit("usage: json_add.py FILE DOT_PATH VALUE_JSON [OWNERSHIP_MARKER]")
    path = Path(sys.argv[1])
    marker = Path(sys.argv[4]) if len(sys.argv) == 5 else None
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    keys = sys.argv[2].split(".")
    parent = data
    for key in keys[:-1]:
        child = parent.get(key)
        if child is None:
            child = {}
            parent[key] = child
        if not isinstance(child, dict):
            raise SystemExit(2)
        parent = child
    key = keys[-1]
    value = json.loads(sys.argv[3])
    if key in parent and parent[key] != value:
        raise SystemExit(2)
    added = key not in parent
    parent[key] = value
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")
    if added and marker is not None:
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.touch()


if __name__ == "__main__":
    main()
