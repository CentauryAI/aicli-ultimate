#!/usr/bin/env python3
import json
import os
import pathlib
import re
import sys
import tempfile
import tomllib

STATUS_LINE = (
    'status_line = ["model-with-reasoning", "current-dir", "git-branch", '
    '"context-remaining", "five-hour-limit", "weekly-limit"] '
    '# aicli-ultimate-owned'
)
TUI_HEADER = re.compile(r"^\s*\[\s*tui\s*\]\s*(?:#.*)?$")
TABLE_HEADER = re.compile(r"^\s*\[")


def atomic_write(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise


def load(path: pathlib.Path) -> tuple[str, dict]:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    return text, tomllib.loads(text) if text.strip() else {}


def save_state(path: pathlib.Path, *, original_exists: bool, created_table: bool) -> None:
    atomic_write(
        path,
        json.dumps(
            {"original_exists": original_exists, "created_table": created_table},
            separators=(",", ":"),
        )
        + "\n",
    )


def install(config: pathlib.Path, state: pathlib.Path) -> None:
    original_exists = config.exists()
    text, data = load(config)
    tui = data.get("tui", {})
    if isinstance(tui, dict) and "status_line" in tui:
        return

    lines = text.splitlines(keepends=True)
    header = next((index for index, line in enumerate(lines) if TUI_HEADER.match(line)), None)
    created_table = header is None
    if header is not None:
        if not lines[header].endswith(("\n", "\r")):
            lines[header] += "\n"
        lines.insert(header + 1, STATUS_LINE + "\n")
        updated = "".join(lines)
    elif "tui" in data:
        raise ValueError("unsupported existing tui table syntax; keeping config unchanged")
    else:
        separator = "" if not text else "\n" if text.endswith("\n") else "\n\n"
        updated = f"{text}{separator}[tui]\n{STATUS_LINE}\n"

    tomllib.loads(updated)
    atomic_write(config, updated)
    save_state(state, original_exists=original_exists, created_table=created_table)


def restore(config: pathlib.Path, state: pathlib.Path) -> None:
    if not state.exists():
        return
    metadata = json.loads(state.read_text(encoding="utf-8"))
    if not config.exists():
        state.unlink()
        return

    text = config.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    owned = [index for index, line in enumerate(lines) if line.rstrip("\r\n") == STATUS_LINE]
    if len(owned) != 1:
        raise ValueError("owned Codex status_line changed; keeping config and state unchanged")
    owned_index = owned[0]
    del lines[owned_index]

    if metadata.get("created_table"):
        header = next(
            (index for index in range(owned_index - 1, -1, -1) if TUI_HEADER.match(lines[index])),
            None,
        )
        if header is not None:
            end = next(
                (index for index in range(header + 1, len(lines)) if TABLE_HEADER.match(lines[index])),
                len(lines),
            )
            if all(not line.strip() for line in lines[header + 1 : end]):
                del lines[header:end]

    updated = "".join(lines)
    if updated.strip():
        tomllib.loads(updated)
        atomic_write(config, updated)
    elif metadata.get("original_exists"):
        atomic_write(config, updated)
    else:
        config.unlink()
    state.unlink()


def main() -> None:
    if len(sys.argv) != 4 or sys.argv[1] not in {"install", "restore"}:
        raise SystemExit(f"usage: {sys.argv[0]} install|restore CONFIG STATE")
    action, config, state = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
    try:
        (install if action == "install" else restore)(config, state)
    except (OSError, ValueError, json.JSONDecodeError, tomllib.TOMLDecodeError) as error:
        print(f"codex statusline: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
