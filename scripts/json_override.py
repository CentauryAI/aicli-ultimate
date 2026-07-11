#!/usr/bin/env python3
"""Override one JSON path reversibly while preserving every unrelated key."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def parent_for(data: dict, keys: list[str], create: bool) -> dict | None:
    current = data
    for key in keys[:-1]:
        child = current.get(key)
        if child is None and create:
            child = {}
            current[key] = child
        if not isinstance(child, dict):
            return None
        current = child
    return current


def load_object(path: Path) -> dict:
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    return data


def write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def set_value(path: Path, keys: list[str], value: object, state: Path) -> None:
    data = load_object(path)
    parent = parent_for(data, keys, create=True)
    if parent is None:
        raise SystemExit(f"cannot set {'.'.join(keys)} through a non-object value")
    if state.exists():
        saved = json.loads(state.read_text())
        if "installed_value" in saved:
            current = parent.get(keys[-1])
            if current != saved["installed_value"] and current != value:
                raise SystemExit(3)
        saved["installed_value"] = value
        state.write_text(json.dumps(saved, indent=2) + "\n")
    else:
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text(
            json.dumps(
                {
                    "existed": keys[-1] in parent,
                    "value": parent.get(keys[-1]),
                    "installed_value": value,
                },
                indent=2,
            )
            + "\n"
        )
    parent[keys[-1]] = value
    write(path, data)


def restore_value(path: Path, keys: list[str], expected: object, state: Path) -> None:
    if not path.exists() or not state.exists():
        return
    data = load_object(path)
    parent = parent_for(data, keys, create=False)
    if parent is None or parent.get(keys[-1]) != expected:
        return
    previous = json.loads(state.read_text())
    if previous.get("existed"):
        parent[keys[-1]] = previous.get("value")
    else:
        parent.pop(keys[-1], None)
    write(path, data)


def migrate_value(
    path: Path, keys: list[str], old: object, new: object, state: Path
) -> None:
    """Accept an application-normalized installed value without losing history."""
    if not path.exists() or not state.exists():
        return
    data = load_object(path)
    parent = parent_for(data, keys, create=False)
    saved = json.loads(state.read_text())
    if parent is None or parent.get(keys[-1]) != new:
        return
    if saved.get("installed_value") == old:
        saved["installed_value"] = new
        state.write_text(json.dumps(saved, indent=2) + "\n")


def main() -> None:
    if len(sys.argv) < 6 or sys.argv[1] not in {"set", "restore", "migrate"}:
        raise SystemExit(
            "usage: json_override.py set|restore FILE DOT_PATH VALUE_JSON STATE_FILE\n"
            "       json_override.py migrate FILE DOT_PATH OLD_JSON NEW_JSON STATE_FILE"
        )
    action = sys.argv[1]
    path = Path(sys.argv[2])
    keys = sys.argv[3].split(".")
    if action == "migrate":
        if len(sys.argv) != 7:
            raise SystemExit("migrate requires OLD_JSON NEW_JSON STATE_FILE")
        migrate_value(
            path,
            keys,
            json.loads(sys.argv[4]),
            json.loads(sys.argv[5]),
            Path(sys.argv[6]),
        )
        return
    if len(sys.argv) != 6:
        raise SystemExit("set/restore require VALUE_JSON STATE_FILE")
    value, state = json.loads(sys.argv[4]), Path(sys.argv[5])
    if action == "set":
        set_value(path, keys, value, state)
    else:
        restore_value(path, keys, value, state)


if __name__ == "__main__":
    main()
