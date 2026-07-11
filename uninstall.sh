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
  remove_skill_source "$target" "$INSTALL_DIR/plugins/apollo-rust-best-practices/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/caveman/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/ponytail/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/centaury-workflow/skills"
  remove_skill_source "$target" "$INSTALL_DIR/plugins/orquestrator/skills"
}

remove_owned_integration() {
  local marker="$1" description="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    rm -f "$marker"
  else
    printf 'Could not remove %s; ownership marker retained: %s\n' "$description" "$marker" >&2
  fi
}

remove_hcom_hooks() {
  local marker_dir="$CONFIG_HOME/hcom-hooks" hcom_bin="" marker tool candidate
  [[ -d "$marker_dir" ]] || return 0
  for candidate in "$(command -v hcom 2>/dev/null || true)" "$BIN_DIR/hcom" \
    "$HOME/.local/bin/hcom" "$HOME/.cargo/bin/hcom"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      hcom_bin="$candidate"
      break
    fi
  done
  for marker in "$marker_dir"/*; do
    [[ -f "$marker" ]] || continue
    tool="$(basename "$marker")"
    if [[ -n "$hcom_bin" ]]; then
      remove_owned_integration "$marker" "HCOM hooks for $tool" "$hcom_bin" hooks remove "$tool"
    else
      printf 'Could not remove HCOM hooks for %s; ownership marker retained: %s\n' \
        "$tool" "$marker" >&2
    fi
  done
  rmdir "$marker_dir" 2>/dev/null || true
}

remove_native_plugins() {
  local native="$CONFIG_HOME/native-plugins" marker plugin tool
  if command -v claude >/dev/null 2>&1; then
    for tool in caveman ponytail rust-analyzer-lsp typescript-lsp pyright-lsp github-lsp; do
      marker="$native/claude-installed-$tool"
      if [[ -f "$marker" ]]; then
        case "$tool" in
          github-lsp) plugin="$tool@aicli-ultimate" ;;
          *-lsp) plugin="$tool@claude-plugins-official" ;;
          *) plugin="$tool@$tool" ;;
        esac
        remove_owned_integration "$marker" "Claude plugin $tool" claude plugin uninstall "$plugin"
      else
        marker="$native/claude-enabled-$tool"
        if [[ -f "$marker" ]]; then
          case "$tool" in
            github-lsp) plugin="$tool@aicli-ultimate" ;;
            *-lsp) plugin="$tool@claude-plugins-official" ;;
            *) plugin="$tool@$tool" ;;
          esac
          remove_owned_integration "$marker" "Claude plugin enablement $tool" claude plugin disable "$plugin"
        fi
      fi
      marker="$native/claude-marketplace-$tool"
      if [[ -f "$marker" && ! -f "$native/claude-installed-$tool" ]]; then
        remove_owned_integration "$marker" "Claude marketplace $tool" claude plugin marketplace remove "$tool"
      fi
    done
    marker="$native/claude-marketplace-claude-plugins-official"
    if [[ -f "$marker" \
      && ! -f "$native/claude-installed-rust-analyzer-lsp" \
      && ! -f "$native/claude-enabled-rust-analyzer-lsp" \
      && ! -f "$native/claude-installed-typescript-lsp" \
      && ! -f "$native/claude-enabled-typescript-lsp" \
      && ! -f "$native/claude-installed-pyright-lsp" \
      && ! -f "$native/claude-enabled-pyright-lsp" ]]; then
      remove_owned_integration "$marker" "Claude official plugin marketplace" \
        claude plugin marketplace remove claude-plugins-official
    fi
    marker="$native/claude-marketplace-aicli-ultimate"
    if [[ -f "$marker" \
      && ! -f "$native/claude-installed-github-lsp" \
      && ! -f "$native/claude-enabled-github-lsp" ]]; then
      remove_owned_integration "$marker" "Claude AI CLI Ultimate marketplace" \
        claude plugin marketplace remove aicli-ultimate
    fi
  fi
  marker="$native/omp-ponytail"
  if [[ -f "$marker" ]] && command -v omp >/dev/null 2>&1; then
    remove_owned_integration "$marker" "OMP plugin Ponytail" omp plugin uninstall @dietrichgebert/ponytail
  fi
  if command -v agy >/dev/null 2>&1; then
    for tool in caveman ponytail; do
      marker="$native/antigravity-$tool"
      if [[ -f "$marker" ]]; then
        remove_owned_integration "$marker" "Antigravity plugin $tool" agy plugin uninstall "$tool"
      fi
    done
  fi
  rmdir "$native" 2>/dev/null || true
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
  codex_native="$CONFIG_HOME/native-plugins"
  codex plugin remove caveman@aicli-ultimate 2>/dev/null || true
  codex plugin remove ponytail@aicli-ultimate 2>/dev/null || true
  codex plugin remove centaury-workflow@aicli-ultimate 2>/dev/null || true
  codex plugin remove orquestrator@aicli-ultimate 2>/dev/null || true
  marker="$codex_native/codex-apollo-rust-best-practices"
  if [[ -f "$marker" ]]; then
    remove_owned_integration "$marker" "Codex Apollo Rust plugin" \
      codex plugin remove apollo-rust-best-practices@aicli-ultimate
  fi
  marker="$codex_native/codex-marketplace-aicli-ultimate"
  if [[ -f "$marker" && ! -f "$codex_native/codex-apollo-rust-best-practices" ]]; then
    remove_owned_integration "$marker" "Codex AI CLI Ultimate marketplace" \
      codex plugin marketplace remove aicli-ultimate
  fi
fi
remove_hcom_hooks
remove_native_plugins
if command -v agy >/dev/null 2>&1; then
  agy plugin uninstall aicli-ultimate >/dev/null 2>&1 || true
fi

remove_shell_block
remove_managed_block "$CODEX_HOME/AGENTS.md"
remove_managed_block "$HOME/.claude/CLAUDE.md"
remove_managed_block "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md"
remove_managed_block "$HOME/AGENTS.md"

if [[ -f "$INSTALL_DIR/scripts/json_remove.py" ]]; then
  if [[ -f "$INSTALL_DIR/scripts/json_lsp.py" ]]; then
    python3 "$INSTALL_DIR/scripts/json_lsp.py" remove \
      "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" github-lsp \
      "$CONFIG_HOME/opencode-github-lsp-state.json"
  fi
  python3 "$INSTALL_DIR/scripts/json_remove.py" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json" theme '"tokyonight"'
  if [[ -f "$CONFIG_HOME/opencode-lsp-owned" ]]; then
    python3 "$INSTALL_DIR/scripts/json_remove.py" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" lsp true
    rm -f "$CONFIG_HOME/opencode-lsp-owned"
  fi
  if [[ -f "$CONFIG_HOME/opencode-lsp-permission-owned" ]]; then
    python3 "$INSTALL_DIR/scripts/json_remove.py" \
      "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" permission.lsp '"allow"'
    rm -f "$CONFIG_HOME/opencode-lsp-permission-owned"
  fi
fi

if [[ -f "$INSTALL_DIR/scripts/json_array.py" ]]; then
  if [[ -f "$CONFIG_HOME/opencode-ponytail-owned" ]]; then
    python3 "$INSTALL_DIR/scripts/json_array.py" remove \
      "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" plugin '"@dietrichgebert/ponytail"'
  fi
  opencode_plugin="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/aicli-ultimate/statusline.js"
  opencode_plugin_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$opencode_plugin")"
  python3 "$INSTALL_DIR/scripts/json_array.py" remove \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json" plugin "$opencode_plugin_json"
  legacy_opencode_plugin="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins/aicli-ultimate-statusline.js"
  legacy_opencode_plugin_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$legacy_opencode_plugin")"
  python3 "$INSTALL_DIR/scripts/json_array.py" remove \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json" plugin "$legacy_opencode_plugin_json"
fi
if [[ -f "$INSTALL_DIR/scripts/json_object_remove.py" ]]; then
  if [[ -f "$CONFIG_HOME/omp-github-lsp-owned" ]]; then
    omp_lsp_json='{"command":"github-lsp","args":[],"fileTypes":[".md",".markdown"],"rootMarkers":[".git"]}'
    python3 "$INSTALL_DIR/scripts/json_object_remove.py" \
      "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/lsp.json" servers github-lsp "$omp_lsp_json"
    rm -f "$CONFIG_HOME/omp-github-lsp-owned"
  fi
  python3 "$INSTALL_DIR/scripts/json_object_remove.py" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/package.json" dependencies '@opentui/core' '"*"'
fi

if [[ -f "$INSTALL_DIR/scripts/json_override.py" ]]; then
  claude_status_json="$(python3 -c 'import json,sys; print(json.dumps({"type":"command","command":sys.argv[1]}))' "$BIN_DIR/claude-ultimate-status")"
  python3 "$INSTALL_DIR/scripts/json_override.py" restore "$HOME/.claude/settings.json" statusLine \
    "$claude_status_json" "$CONFIG_HOME/claude-statusline-previous.json"
  antigravity_status_json="$(python3 -c 'import json,sys; print(json.dumps({"type":"","command":sys.argv[1],"enabled":True}))' "$BIN_DIR/antigravity-ultimate-status")"
  python3 "$INSTALL_DIR/scripts/json_override.py" restore \
    "$HOME/.gemini/antigravity-cli/settings.json" statusLine \
    "$antigravity_status_json" "$CONFIG_HOME/antigravity-statusline-previous.json"
fi

if [[ -f "$CONFIG_HOME/omp-statusline-owned" ]] && command -v omp >/dev/null 2>&1; then
  preset="$(omp config get statusLine.preset --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("value", ""))' || true)"
  separator="$(omp config get statusLine.separator --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("value", ""))' || true)"
  [[ "$preset" == full ]] && omp config reset statusLine.preset >/dev/null 2>&1 || true
  [[ "$separator" == powerline ]] && omp config reset statusLine.separator >/dev/null 2>&1 || true
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
remove_generated_file "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/aicli-ultimate/statusline.js" "$INSTALL_DIR/statusline/opencode-powerline.js"
remove_generated_file "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins/aicli-ultimate-statusline.js" "$INSTALL_DIR/statusline/opencode-powerline.js"
remove_generated_file "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/extensions/aicli-ultimate-statusline.ts" "$INSTALL_DIR/statusline/omp-powerline.ts"
remove_generated_file "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/hooks/aicli-ultimate-statusline.ts" "$INSTALL_DIR/statusline/omp-powerline.ts"
remove_generated_file "$BIN_DIR/antigravity-ultimate-status" "$INSTALL_DIR/statusline/antigravity-powerline"
remove_generated_file "$BIN_DIR/aicli-mcpls" "$INSTALL_DIR/config/mcpls.toml"
remove_generated_file "$BIN_DIR/github-lsp" "$INSTALL_DIR/plugins/github-lsp/.lsp.json"
remove_generated_file "$CONFIG_HOME/mcpls.toml" "$INSTALL_DIR/config/mcpls.toml"

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
  "$CONFIG_HOME/antigravity-statusline-previous.json" "$CONFIG_HOME/omp-statusline-owned" \
  "$CONFIG_HOME/opencode-ponytail-owned" \
  "$CONFIG_HOME/manifest.txt" "$CONFIG_HOME/manifest.txt.new" \
  "$CONFIG_HOME/install-state.json"

printf 'AI CLI Ultimate removed. Backups were preserved in %s/backups.\n' "$CONFIG_HOME"
