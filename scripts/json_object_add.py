#!/usr/bin/env python3
"""Add one literal key to a top-level JSON object without replacing it."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("usage: json_object_add.py FILE OBJECT_KEY KEY VALUE_JSON")
    filename, object_key, key, raw_value = sys.argv[1:]
    path = Path(filename)
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    target = data.setdefault(object_key, {})
    if not isinstance(target, dict):
        raise SystemExit(f"{object_key} must contain a JSON object")
    value = json.loads(raw_value)
    if key in target and target[key] != value:
        raise SystemExit(2)
    target[key] = value
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
