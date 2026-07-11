#!/usr/bin/env python3
"""Add or remove one value in a top-level JSON array without touching peers."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 5 or sys.argv[1] not in {"add", "remove"}:
        raise SystemExit("usage: json_array.py add|remove FILE KEY VALUE_JSON")
    action, filename, key, raw_value = sys.argv[1:]
    path = Path(filename)
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    value = json.loads(raw_value)
    items = data.get(key, [])
    if not isinstance(items, list):
        raise SystemExit(f"{key} must contain a JSON array")
    if action == "add" and value not in items:
        items.append(value)
    elif action == "remove":
        items = [item for item in items if item != value]
    if items:
        data[key] = items
    else:
        data.pop(key, None)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
