#!/usr/bin/env python3
"""Add or remove one OpenCode LSP server without losing prior LSP state."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def load_object(path: Path) -> dict:
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must contain a JSON object")
    return data


def write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def add(path: Path, name: str, value: object, state_path: Path) -> None:
    data = load_object(path)
    current = data.get("lsp")
    if current is False or (current is not None and current is not True and not isinstance(current, dict)):
        raise SystemExit(2)

    servers = {} if current in (None, True) else dict(current)
    if name in servers and servers[name] != value:
        raise SystemExit(2)
    if name in servers and not state_path.exists():
        return

    if state_path.exists():
        state = json.loads(state_path.read_text())
        installed = state.get("installed_value")
        if name in servers and servers[name] not in (installed, value):
            raise SystemExit(3)
        state["installed_value"] = value
    else:
        mode = "true" if current is True else "object" if isinstance(current, dict) else "absent"
        state = {"mode": mode, "installed_value": value}

    servers[name] = value
    data["lsp"] = servers
    write(path, data)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2) + "\n")


def remove(path: Path, name: str, state_path: Path) -> None:
    if not path.exists() or not state_path.exists():
        return
    data = load_object(path)
    state = json.loads(state_path.read_text())
    servers = data.get("lsp")
    if not isinstance(servers, dict):
        return
    if name not in servers:
        state_path.unlink()
        return
    if servers[name] != state.get("installed_value"):
        return

    del servers[name]
    if servers:
        data["lsp"] = servers
    elif state.get("mode") == "true":
        data["lsp"] = True
    elif state.get("mode") == "object":
        data["lsp"] = {}
    else:
        data.pop("lsp", None)
    write(path, data)
    state_path.unlink()


def main() -> None:
    if len(sys.argv) not in {5, 6} or sys.argv[1] not in {"add", "remove"}:
        raise SystemExit("usage: json_lsp.py add FILE NAME VALUE_JSON STATE_FILE\n       json_lsp.py remove FILE NAME STATE_FILE")
    action, filename, name = sys.argv[1:4]
    path = Path(filename)
    if action == "add":
        if len(sys.argv) != 6:
            raise SystemExit("add requires VALUE_JSON STATE_FILE")
        add(path, name, json.loads(sys.argv[4]), Path(sys.argv[5]))
    else:
        if len(sys.argv) != 5:
            raise SystemExit("remove requires STATE_FILE")
        remove(path, name, Path(sys.argv[4]))


if __name__ == "__main__":
    main()
