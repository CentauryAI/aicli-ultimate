#!/usr/bin/env python3
"""Remove one literal object key only when its value is still installer-owned."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("usage: json_object_remove.py FILE OBJECT_KEY KEY VALUE_JSON")
    filename, object_key, key, raw_value = sys.argv[1:]
    path = Path(filename)
    if not path.exists():
        return
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    target = data.get(object_key)
    value = json.loads(raw_value)
    if not isinstance(target, dict) or target.get(key) != value:
        return
    del target[key]
    if not target:
        del data[object_key]
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()
