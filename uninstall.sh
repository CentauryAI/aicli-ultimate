#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/aicli-ultimate"
INSTALL_DIR="${AICLI_ULTIMATE_INSTALL_DIR:-$HOME/.local/share/aicli-ultimate}"
BIN_DIR="${AICLI_ULTIMATE_BIN_DIR:-$HOME/.local/bin}"
NONINTERACTIVE="${AICLI_ULTIMATE_NONINTERACTIVE:-0}"

ask() {
  local prompt="$1" answer
  [[ "$NONINTERACTIVE" == 1 ]] && return 1
  read -r -p "$prompt [y/N] " answer </dev/tty || answer=""
  [[ "${answer:-n}" =~ ^[Yy]$ ]]
}

remove_shell_block() {
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    [[ -f "$rc" ]] || continue
    awk '
      $0 == "# >>> aicli-ultimate >>>" {skip=1; next}
      $0 == "# <<< aicli-ultimate <<<" {skip=0; next}
      !skip {print}
    ' "$rc" >"$rc.tmp"
    mv "$rc.tmp" "$rc"
  done
}

remove_managed_block() {
  local target="$1"
  local start='<!-- >>> aicli-ultimate >>> -->' end='<!-- <<< aicli-ultimate <<< -->'
  [[ -f "$target" ]] || return 0
  awk -v start="$start" -v end="$end" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$target" >"$target.tmp"
  mv "$target.tmp" "$target"
}

remove_generated_file() {
  local installed="$1" generated="$2" marker="$1.aicli-ultimate-owned"
  [[ -e "$installed" ]] || return 0
  if [[ -e "$marker" ]]; then
    rm -f "$installed" "$marker"
  else
    printf 'Preserving unowned file: %s\n' "$installed" >&2
  fi
}

remove_skill_source() {
  local target="$1" source="$2" skill installed
  [[ -d "$source" ]] || return 0
  for skill in "$source"/*; do
    [[ -d "$skill" ]] || continue
    installed="$target/$(basename "$skill")"
    [[ -d "$installed" ]] || continue
    if [[ -e "$installed/.aicli-ultimate-owned" ]]; then
      rm -rf "$installed"
    else
      printf 'Preserving unowned skill: %s\n' "$installed" >&2
    fi
  done
}

remove_skill_set() {
  local target="$1"
  [[ -d "$INSTALL_DIR" ]] || return 0
  remove_skill_source "$target" "$INSTALL_DIR/plugins/caveman/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/ponytail/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/centaury-workflow/skills"
}

remove_git_include() {
  local condition="$1" target="$2" key
  key="includeIf.$condition.path"
  git config --global --fixed-value --unset-all "$key" "$target" 2>/dev/null || true
}

guard_config="$CONFIG_HOME/centaury.gitconfig"
if command -v git >/dev/null 2>&1; then
  remove_git_include 'hasconfig:remote.*.url:https://github.com/CentauryAI/**' "$guard_config"
  remove_git_include 'hasconfig:remote.*.url:git@github.com:CentauryAI/**' "$guard_config"
  remove_git_include 'hasconfig:remote.*.url:ssh://git@github.com/CentauryAI/**' "$guard_config"
  remove_git_include 'hasconfig:remote.*.url:https://github.com/CentuaryAI/**' "$guard_config"
  remove_git_include 'hasconfig:remote.*.url:git@github.com:CentuaryAI/**' "$guard_config"
fi

if command -v codex >/dev/null 2>&1; then
  codex plugin remove caveman@aicli-ultimate 2>/dev/null || true
  codex plugin remove ponytail@aicli-ultimate 2>/dev/null || true
  codex plugin remove centaury-workflow@aicli-ultimate 2>/dev/null || true
  codex plugin marketplace remove aicli-ultimate 2>/dev/null || true
fi
if command -v agy >/dev/null 2>&1; then
  agy plugin uninstall aicli-ultimate >/dev/null 2>&1 || true
fi

remove_shell_block
remove_managed_block "$CODEX_HOME/AGENTS.md"
remove_managed_block "$HOME/.claude/CLAUDE.md"
remove_managed_block "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md"
remove_managed_block "$HOME/AGENTS.md"

if [[ -f "$INSTALL_DIR/scripts/json_remove.py" ]]; then
  python3 "$INSTALL_DIR/scripts/json_remove.py" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json" theme '"tokyonight"'
fi

if [[ -f "$INSTALL_DIR/scripts/json_override.py" ]]; then
  claude_status_json="$(python3 -c 'import json,sys; print(json.dumps({"type":"command","command":sys.argv[1]}))' "$BIN_DIR/claude-ultimate-status")"
  python3 "$INSTALL_DIR/scripts/json_override.py" restore "$HOME/.claude/settings.json" statusLine \
    "$claude_status_json" "$CONFIG_HOME/claude-statusline-previous.json"
fi

remove_skill_set "$HOME/.claude/skills"
remove_skill_set "$HOME/.agents/skills"
if [[ -d "$INSTALL_DIR/adapters/claude/agents" ]]; then
  for file in "$INSTALL_DIR/adapters/claude/agents/"*.md; do
    remove_generated_file "$HOME/.claude/agents/$(basename "$file")" "$file"
  done
fi
if [[ -d "$INSTALL_DIR/adapters/opencode/agents" ]]; then
  for file in "$INSTALL_DIR/adapters/opencode/agents/"*.md; do
    remove_generated_file "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents/$(basename "$file")" "$file"
  done
fi

remove_generated_file "$CODEX_HOME/aicli-ultimate.config.toml" "$INSTALL_DIR/config/ultimate.config.toml"
if [[ -d "$INSTALL_DIR/config/agents" ]]; then
  for file in "$INSTALL_DIR/config/agents/"*.toml; do
    remove_generated_file "$CODEX_HOME/agents/$(basename "$file")" "$file"
  done
fi
remove_generated_file "$CODEX_HOME/themes/midnight-blue.tmTheme" "$INSTALL_DIR/config/themes/midnight-blue.tmTheme"

if [[ -e "$HOME/.gemini/config/plugins/aicli-ultimate/.aicli-ultimate-owned" ]]; then
  rm -rf "$HOME/.gemini/config/plugins/aicli-ultimate"
fi
remove_generated_file "$BIN_DIR/aicli-ultimate" "$INSTALL_DIR/statusline/codex-powerline"
remove_generated_file "$BIN_DIR/aicli-ultimate-status" "$INSTALL_DIR/statusline/codex-powerline-status"
remove_generated_file "$BIN_DIR/claude-ultimate-status" "$INSTALL_DIR/statusline/claude-powerline-status"
remove_generated_file "$BIN_DIR/aicli-agent-status" "$INSTALL_DIR/statusline/aicli-agent-status"
remove_generated_file "$BIN_DIR/aicli-opencode" "$INSTALL_DIR/statusline/aicli-agent-powerline"
remove_generated_file "$BIN_DIR/aicli-omp" "$INSTALL_DIR/statusline/aicli-agent-powerline"
remove_generated_file "$BIN_DIR/aicli-agy" "$INSTALL_DIR/statusline/aicli-agent-powerline"

backup=""
if [[ -r "$CONFIG_HOME/install-state.json" ]]; then
  backup="$(python3 - "$CONFIG_HOME/install-state.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("backup", ""))
except (OSError, ValueError):
    pass
PY
)"
fi

if [[ -n "$backup" ]] && ask "Restore files from $backup? This overwrites post-install edits."; then
  cp -a "$backup/." "$HOME/"
fi

rm -rf "$INSTALL_DIR"
rm -rf "$CONFIG_HOME/git-hooks"
rm -f "$CONFIG_HOME/centaury.gitconfig" "$CONFIG_HOME/modes" "$CONFIG_HOME/tmux.conf" \
  "$CONFIG_HOME/tmux-opencode.conf" "$CONFIG_HOME/tmux-omp.conf" "$CONFIG_HOME/tmux-agy.conf" \
  "$CONFIG_HOME/claude-statusline-previous.json" "$CONFIG_HOME/profile-state.json" \
  "$CONFIG_HOME/install-state.json"

printf 'AI CLI Ultimate removed. Backups were preserved in %s/backups.\n' "$CONFIG_HOME"
