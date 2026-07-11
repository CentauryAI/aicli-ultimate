#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${AICLI_ULTIMATE_REPO:-CentauryAI/aicli-ultimate}"
REF="${AICLI_ULTIMATE_REF:-main}"
NONINTERACTIVE="${AICLI_ULTIMATE_NONINTERACTIVE:-0}"
DRY_RUN="${AICLI_ULTIMATE_DRY_RUN:-0}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/aicli-ultimate"
INSTALL_DIR="${AICLI_ULTIMATE_INSTALL_DIR:-$HOME/.local/share/aicli-ultimate}"
BIN_DIR="${AICLI_ULTIMATE_BIN_DIR:-$HOME/.local/bin}"
STATE_FILE="$CONFIG_HOME/install-state.json"
TEMP_DIR=""

cleanup() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  return 0
}
trap cleanup EXIT

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

ask() {
  local prompt="$1" default="${2:-y}" answer
  if [[ "$NONINTERACTIVE" == 1 ]]; then
    [[ "$default" == y ]]
    return
  fi
  if [[ "$default" == y ]]; then
    read -r -p "$prompt [Y/n] " answer </dev/tty || answer=""
    [[ "${answer:-y}" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " answer </dev/tty || answer=""
    [[ "${answer:-n}" =~ ^[Yy]$ ]]
  fi
}

resolve_source() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [[ -f "$script_dir/config/ultimate.config.toml" ]]; then
    ROOT="$script_dir"
    return
  fi
  command -v curl >/dev/null || die "curl is required"
  command -v tar >/dev/null || die "tar is required"
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate.XXXXXX")"
  info "Downloading $REPO_SLUG@$REF" >&2
  curl -fsSL "https://github.com/$REPO_SLUG/archive/refs/heads/$REF.tar.gz" \
    | tar -xz -C "$TEMP_DIR" --strip-components=1
  ROOT="$TEMP_DIR"
}

install_codex_if_missing() {
  command -v codex >/dev/null 2>&1 && return
  ask "Codex CLI is missing. Install @openai/codex with npm?" y || die "Codex CLI is required"
  command -v npm >/dev/null || die "npm is required to install Codex automatically"
  [[ "$DRY_RUN" == 1 ]] || npm install -g @openai/codex
}

backup_file() {
  local file="$1" backup="$2"
  [[ -e "$file" ]] || return 0
  mkdir -p "$backup/$(dirname "${file#$HOME/}")"
  cp -a "$file" "$backup/${file#$HOME/}"
}

render_agents() {
  local source="$1" target="$2" caveman_rule="" ponytail_rule=""
  [[ "$CAVEMAN_ALWAYS" == 1 ]] && caveman_rule='- Keep Caveman output mode active: terse output with full technical substance. Disable only when the user says “stop caveman”.'
  [[ "$PONYTAIL_ALWAYS" == 1 ]] && ponytail_rule='- Keep Ponytail engineering mode active: YAGNI, standard library first, native features before dependencies, and the smallest correct implementation.'
  sed \
    -e "s|@CAVEMAN_RULE@|$caveman_rule|" \
    -e "s|@PONYTAIL_RULE@|$ponytail_rule|" \
    "$source" >"$target"
}

configure_shell() {
  local rc marker_start='# >>> aicli-ultimate >>>' marker_end='# <<< aicli-ultimate <<<'
  case "${SHELL##*/}" in
    zsh) rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *) rc="$HOME/.profile" ;;
  esac
  touch "$rc"
  awk -v start="$marker_start" -v end="$marker_end" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$rc" >"$rc.tmp"
  mv "$rc.tmp" "$rc"
  {
    printf '\n%s\n' "$marker_start"
    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    [[ "$TARGET_CODEX" == 1 ]] && printf "alias codex='aicli-ultimate'\n"
    if [[ "$COMPLETIONS" == 1 ]]; then
      if [[ "$TARGET_CODEX" == 1 && "${SHELL##*/}" == zsh ]]; then
        printf 'autoload -Uz compinit && compinit\n'
        printf 'eval "$(command codex completion zsh)"\n'
      elif [[ "$TARGET_CODEX" == 1 && "${SHELL##*/}" == bash ]]; then
        printf 'source <(command codex completion bash)\n'
      fi
      if [[ "$TARGET_OMP" == 1 ]]; then
        printf 'eval "$(command omp completions %s)"\n' "${SHELL##*/}"
      fi
    fi
    printf '%s\n' "$marker_end"
  } >>"$rc"
}

upsert_managed_block() {
  local target="$1" content="$2"
  local start='<!-- >>> aicli-ultimate >>> -->' end='<!-- <<< aicli-ultimate <<< -->'
  mkdir -p "$(dirname "$target")"
  touch "$target"
  awk -v start="$start" -v end="$end" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$target" >"$target.tmp"
  mv "$target.tmp" "$target"
  {
    printf '\n%s\n' "$start"
    cat "$content"
    printf '%s\n' "$end"
  } >>"$target"
}

copy_skill_source() {
  local target="$1" source="$2" skill destination marker
  for skill in "$source"/*; do
    [[ -d "$skill" ]] || continue
    destination="$target/$(basename "$skill")"
    marker="$destination/.aicli-ultimate-owned"
    if [[ -e "$destination" && ! -e "$marker" ]]; then
      warn "Keeping existing skill (not owned by AI CLI Ultimate): $destination"
      continue
    fi
    rm -rf "$destination"
    cp -R "$skill" "$destination"
    touch "$marker"
  done
}

install_owned_file() {
  local source="$1" target="$2" marker="$2.aicli-ultimate-owned"
  if [[ -e "$target" && ! -e "$marker" ]]; then
    warn "Keeping existing file (not owned by AI CLI Ultimate): $target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"
  touch "$marker"
}

copy_skill_set() {
  local target="$1"
  mkdir -p "$target"
  if [[ "$CAVEMAN" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/caveman/skills"; fi
  if [[ "$PONYTAIL" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/ponytail/skills"; fi
  if [[ "$CENTAURY" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/centaury-workflow/skills"; fi
}

backup_skill_source() {
  local target="$1" backup="$2" source="$3" skill
  for skill in "$source"/*; do
    [[ -d "$skill" ]] || continue
    backup_file "$target/$(basename "$skill")" "$backup"
  done
}

backup_skill_set() {
  local target="$1" backup="$2"
  if [[ "$CAVEMAN" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/caveman/skills"; fi
  if [[ "$PONYTAIL" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/ponytail/skills"; fi
  if [[ "$CENTAURY" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/centaury-workflow/skills"; fi
}

configure_antigravity() {
  local target="$HOME/.gemini/config/plugins/aicli-ultimate"
  if [[ -e "$target" && ! -e "$target/.aicli-ultimate-owned" ]]; then
    warn "Keeping existing Antigravity plugin: $target"
    return 0
  fi
  mkdir -p "$target/rules"
  touch "$target/.aicli-ultimate-owned"
  cp "$ROOT/adapters/antigravity/plugin.json" "$target/plugin.json"
  cp "$CONFIG_HOME/global-instructions.md" "$target/rules/global.md"
  copy_skill_set "$target/skills"
  if command -v agy >/dev/null 2>&1 && ! agy plugin validate "$target" >/dev/null; then
    warn "Antigravity rejected the generated plugin; files remain at $target for inspection."
  elif [[ "$DRY_RUN" != 1 ]] && command -v agy >/dev/null 2>&1 \
    && ! agy plugin install "$target" >/dev/null; then
    warn "Antigravity validated the plugin but could not register it."
  fi
}

configure_opencode_statusline() {
  local home="$1" plugin plugin_json legacy legacy_json
  legacy="$home/plugins/aicli-ultimate-statusline.js"
  legacy_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$legacy")"
  python3 "$ROOT/scripts/json_array.py" remove "$home/tui.json" plugin "$legacy_json"
  if [[ -e "$legacy.aicli-ultimate-owned" ]]; then
    rm -f "$legacy" "$legacy.aicli-ultimate-owned"
  fi
  plugin="$home/aicli-ultimate/statusline.js"
  install_owned_file "$ROOT/statusline/opencode-powerline.js" "$plugin"
  plugin_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$plugin")"
  python3 "$ROOT/scripts/json_array.py" add "$home/tui.json" plugin "$plugin_json"
  python3 "$ROOT/scripts/json_object_add.py" "$home/package.json" dependencies '@opentui/core' '"*"' \
    || warn "Keeping the existing OpenCode @opentui/core dependency."
}

configure_omp_statusline() {
  local agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}" config
  config="$agent_dir/config.yml"
  install_owned_file "$ROOT/statusline/omp-powerline.ts" "$agent_dir/extensions/aicli-ultimate-statusline.ts"
  if [[ -e "$agent_dir/hooks/aicli-ultimate-statusline.ts.aicli-ultimate-owned" ]]; then
    rm -f "$agent_dir/hooks/aicli-ultimate-statusline.ts" \
      "$agent_dir/hooks/aicli-ultimate-statusline.ts.aicli-ultimate-owned"
  fi
  if command -v omp >/dev/null 2>&1 && ! grep -Eq '^statusLine:' "$config" 2>/dev/null; then
    if [[ "$DRY_RUN" == 1 ]]; then
      return 0
    elif omp config set statusLine.preset full >/dev/null \
      && omp config set statusLine.separator powerline >/dev/null; then
      touch "$CONFIG_HOME/omp-statusline-owned"
    else
      warn "Could not enable OMP's native full Powerline preset; the additive footer hook was still installed."
    fi
  elif [[ -e "$CONFIG_HOME/omp-statusline-owned" ]]; then
    :
  elif grep -Eq '^statusLine:' "$config" 2>/dev/null; then
    warn "Keeping the existing OMP statusLine configuration; only the additive footer hook was installed."
  fi
}

configure_antigravity_statusline() {
  local settings="$HOME/.gemini/antigravity-cli/settings.json" status_json
  status_json="$(python3 -c 'import json,sys; print(json.dumps({"command":sys.argv[1],"enabled":True,"stack_with_default":False}))' "$BIN_DIR/antigravity-ultimate-status")"
  if python3 "$ROOT/scripts/json_override.py" set "$settings" statusLine \
    "$status_json" "$CONFIG_HOME/antigravity-statusline-previous.json"; then
    install_owned_file "$ROOT/statusline/antigravity-powerline" "$BIN_DIR/antigravity-ultimate-status"
  else
    warn "Keeping an Antigravity statusLine changed after AI CLI Ultimate was installed."
  fi
}

target_selected() {
  case ",${AICLI_ULTIMATE_TARGETS:-}," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

add_git_include() {
  local condition="$1" target="$2" key
  key="includeIf.$condition.path"
  git config --global --get-all "$key" 2>/dev/null | grep -Fxq "$target" \
    || git config --global --add "$key" "$target"
}

configure_centaury_guard() {
  local guard_config="$CONFIG_HOME/centaury.gitconfig" hooks="$CONFIG_HOME/git-hooks"
  mkdir -p "$hooks"
  cp "$ROOT/git-hooks/pre-commit" "$ROOT/git-hooks/pre-push" "$hooks/"
  chmod +x "$hooks/pre-commit" "$hooks/pre-push"
  sed "s|@HOOKS_PATH@|$hooks|" "$ROOT/config/centaury.gitconfig" >"$guard_config"

  add_git_include 'hasconfig:remote.*.url:https://github.com/CentauryAI/**' "$guard_config"
  add_git_include 'hasconfig:remote.*.url:git@github.com:CentauryAI/**' "$guard_config"
  add_git_include 'hasconfig:remote.*.url:ssh://git@github.com/CentauryAI/**' "$guard_config"
  add_git_include 'hasconfig:remote.*.url:https://github.com/CentuaryAI/**' "$guard_config"
  add_git_include 'hasconfig:remote.*.url:git@github.com:CentuaryAI/**' "$guard_config"
}

install_plugin() {
  local plugin="$1" required="${2:-1}" plugin_list
  plugin_list="$(codex plugin list 2>/dev/null || true)"
  if grep -Eq "^${plugin//./\.}[[:space:]]+installed" <<<"$plugin_list"; then
    info "Plugin already installed: $plugin"
  elif ! codex plugin add "$plugin"; then
    if [[ "$required" == 1 ]]; then
      die "failed to install required plugin: $plugin"
    fi
    warn "Optional plugin unavailable: $plugin"
  fi
}

resolve_source
printf '\n\033[1;35mAI CLI Ultimate setup\033[0m\n\n'
command -v python3 >/dev/null || die "python3 is required"

if [[ -n "${AICLI_ULTIMATE_TARGETS:-}" ]]; then
  target_selected codex && TARGET_CODEX=1 || TARGET_CODEX=0
  target_selected claude && TARGET_CLAUDE=1 || TARGET_CLAUDE=0
  target_selected opencode && TARGET_OPENCODE=1 || TARGET_OPENCODE=0
  target_selected omp && TARGET_OMP=1 || TARGET_OMP=0
  target_selected antigravity && TARGET_ANTIGRAVITY=1 || TARGET_ANTIGRAVITY=0
else
  ask "Configure Codex?" y && TARGET_CODEX=1 || TARGET_CODEX=0
  command -v claude >/dev/null 2>&1 && default=y || default=n
  ask "Configure Claude Code?" "$default" && TARGET_CLAUDE=1 || TARGET_CLAUDE=0
  command -v opencode >/dev/null 2>&1 && default=y || default=n
  ask "Configure OpenCode?" "$default" && TARGET_OPENCODE=1 || TARGET_OPENCODE=0
  command -v omp >/dev/null 2>&1 && default=y || default=n
  ask "Configure OMP (Oh My Pi)?" "$default" && TARGET_OMP=1 || TARGET_OMP=0
  command -v agy >/dev/null 2>&1 && default=y || default=n
  ask "Configure Antigravity CLI (agy)?" "$default" && TARGET_ANTIGRAVITY=1 || TARGET_ANTIGRAVITY=0
fi

if (( TARGET_CODEX + TARGET_CLAUDE + TARGET_OPENCODE + TARGET_OMP + TARGET_ANTIGRAVITY == 0 )); then
  die "select at least one target"
fi
[[ "$TARGET_CODEX" == 1 ]] && install_codex_if_missing

EFFORT="${AICLI_ULTIMATE_EFFORT:-xhigh}"
if [[ "$NONINTERACTIVE" != 1 ]]; then
  read -r -p "Reasoning effort [xhigh/high/medium] (xhigh): " EFFORT </dev/tty || EFFORT=xhigh
  EFFORT="${EFFORT:-xhigh}"
fi
[[ "$EFFORT" =~ ^(xhigh|high|medium)$ ]] || die "invalid reasoning effort: $EFFORT"

if (( TARGET_CODEX + TARGET_CLAUDE + TARGET_OPENCODE + TARGET_OMP + TARGET_ANTIGRAVITY > 0 )); then
  ask "Install supported Powerline statuslines?" y && STATUSLINE=1 || STATUSLINE=0
else
  STATUSLINE=0
fi
ask "Install the Caveman plugin?" y && CAVEMAN=1 || CAVEMAN=0
if [[ "$CAVEMAN" == 1 ]] && ask "Keep Caveman active by default?" y; then CAVEMAN_ALWAYS=1; else CAVEMAN_ALWAYS=0; fi
ask "Install the Ponytail plugin?" y && PONYTAIL=1 || PONYTAIL=0
if [[ "$PONYTAIL" == 1 ]] && ask "Keep Ponytail active by default?" y; then PONYTAIL_ALWAYS=1; else PONYTAIL_ALWAYS=0; fi
if [[ "$TARGET_CODEX" == 1 ]]; then
  ask "Install the official Superpowers plugin?" y && SUPERPOWERS=1 || SUPERPOWERS=0
else
  SUPERPOWERS=0
fi
ask "Enable the CentauryAI protected-branch workflow?" y && CENTAURY=1 || CENTAURY=0
ask "Install shell completions?" y && COMPLETIONS=1 || COMPLETIONS=0
ask "Install optional frontend skills?" n && FRONTEND=1 || FRONTEND=0
ask "Install optional Playwright testing skill?" n && PLAYWRIGHT=1 || PLAYWRIGHT=0
ask "Install optional React best-practices skill?" n && REACT=1 || REACT=0
if [[ "$TARGET_CODEX" == 1 ]]; then
  ask "Install the official Codex Security plugin?" n && SECURITY=1 || SECURITY=0
else
  SECURITY=0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup="$CONFIG_HOME/backups/$timestamp"
mkdir -p "$backup"
for file in "$CODEX_HOME/config.toml" "$CODEX_HOME/aicli-ultimate.config.toml" "$CODEX_HOME/AGENTS.md" \
  "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/package.json" "$HOME/AGENTS.md" \
  "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/config.yml" \
  "$HOME/.gemini/antigravity-cli/settings.json" \
  "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  backup_file "$file" "$backup"
done

if [[ "$TARGET_CLAUDE" == 1 ]]; then
  backup_skill_set "$HOME/.claude/skills" "$backup"
  for file in "$ROOT/adapters/claude/agents/"*.md; do
    backup_file "$HOME/.claude/agents/$(basename "$file")" "$backup"
  done
  backup_file "$BIN_DIR/claude-ultimate-status" "$backup"
fi
if [[ "$TARGET_OPENCODE" == 1 || "$TARGET_OMP" == 1 ]]; then
  backup_skill_set "$HOME/.agents/skills" "$backup"
fi
if [[ "$TARGET_OPENCODE" == 1 ]]; then
  for file in "$ROOT/adapters/opencode/agents/"*.md; do
    backup_file "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents/$(basename "$file")" "$backup"
  done
  backup_file "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/aicli-ultimate/statusline.js" "$backup"
fi
if [[ "$TARGET_OMP" == 1 ]]; then
  backup_file "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/extensions/aicli-ultimate-statusline.ts" "$backup"
fi
if [[ "$TARGET_ANTIGRAVITY" == 1 ]]; then
  backup_file "$HOME/.gemini/config/plugins/aicli-ultimate" "$backup"
fi
backup_file "$BIN_DIR/aicli-ultimate" "$backup"
backup_file "$BIN_DIR/aicli-ultimate-status" "$backup"
backup_file "$BIN_DIR/aicli-agent-status" "$backup"
backup_file "$BIN_DIR/aicli-opencode" "$backup"
backup_file "$BIN_DIR/aicli-omp" "$backup"
backup_file "$BIN_DIR/aicli-agy" "$backup"

info "Installing files"
mkdir -p "$INSTALL_DIR" "$CONFIG_HOME" "$BIN_DIR"
if [[ "$ROOT" != "$INSTALL_DIR" ]]; then
  (cd "$ROOT" && tar --exclude=.git -cf - .) | (cd "$INSTALL_DIR" && tar -xf -)
fi

render_agents "$ROOT/config/AGENTS.md" "$CONFIG_HOME/global-instructions.md"

if [[ "$TARGET_CODEX" == 1 ]]; then
  mkdir -p "$CODEX_HOME/agents" "$CODEX_HOME/themes"
  status_value='status_line = ["model-with-reasoning", "current-dir", "git-branch", "context-remaining", "five-hour-limit", "weekly-limit"]'
  [[ "$STATUSLINE" == 1 ]] && status_value='# Native status line disabled; external Powerline wrapper is active.'
  sed \
    -e "s|@EFFORT@|$EFFORT|" \
    -e "s|@CODEX_HOME@|$CODEX_HOME|g" \
    -e "s|@STATUS_LINE_CONFIG@|$status_value|" \
    "$ROOT/config/ultimate.config.toml" >"$CONFIG_HOME/aicli-ultimate.config.toml.rendered"
  install_owned_file "$CONFIG_HOME/aicli-ultimate.config.toml.rendered" "$CODEX_HOME/aicli-ultimate.config.toml"
  for file in "$ROOT/config/agents/"*.toml; do
    install_owned_file "$file" "$CODEX_HOME/agents/$(basename "$file")"
  done
  install_owned_file "$ROOT/config/themes/midnight-blue.tmTheme" "$CODEX_HOME/themes/midnight-blue.tmTheme"
  upsert_managed_block "$CODEX_HOME/AGENTS.md" "$CONFIG_HOME/global-instructions.md"
fi

if [[ "$TARGET_CLAUDE" == 1 ]]; then
  upsert_managed_block "$HOME/.claude/CLAUDE.md" "$CONFIG_HOME/global-instructions.md"
  copy_skill_set "$HOME/.claude/skills"
  mkdir -p "$HOME/.claude/agents"
  for file in "$ROOT/adapters/claude/agents/"*.md; do
    install_owned_file "$file" "$HOME/.claude/agents/$(basename "$file")"
  done
  if [[ "$STATUSLINE" == 1 ]]; then
    claude_status_json="$(python3 -c 'import json,sys; print(json.dumps({"type":"command","command":sys.argv[1]}))' "$BIN_DIR/claude-ultimate-status")"
    if python3 "$ROOT/scripts/json_override.py" set "$HOME/.claude/settings.json" statusLine \
      "$claude_status_json" "$CONFIG_HOME/claude-statusline-previous.json"; then
      install_owned_file "$ROOT/statusline/claude-powerline-status" "$BIN_DIR/claude-ultimate-status"
    else
      warn "Keeping a Claude statusLine changed after AI CLI Ultimate was installed."
    fi
  fi
fi

if [[ "$TARGET_OPENCODE" == 1 ]]; then
  opencode_home="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
  upsert_managed_block "$opencode_home/AGENTS.md" "$CONFIG_HOME/global-instructions.md"
  mkdir -p "$opencode_home/agents"
  for file in "$ROOT/adapters/opencode/agents/"*.md; do
    install_owned_file "$file" "$opencode_home/agents/$(basename "$file")"
  done
  python3 "$ROOT/scripts/json_add.py" "$opencode_home/tui.json" '$schema' '"https://opencode.ai/tui.json"' \
    || warn "Keeping the existing OpenCode TUI schema."
  python3 "$ROOT/scripts/json_add.py" "$opencode_home/tui.json" theme '"tokyonight"' \
    || warn "Keeping the existing OpenCode theme."
  [[ "$STATUSLINE" == 1 ]] && configure_opencode_statusline "$opencode_home"
fi

if [[ "$TARGET_OMP" == 1 ]]; then
  upsert_managed_block "$HOME/AGENTS.md" "$CONFIG_HOME/global-instructions.md"
  [[ "$STATUSLINE" == 1 ]] && configure_omp_statusline
fi

if [[ "$TARGET_OPENCODE" == 1 || "$TARGET_OMP" == 1 ]]; then
  copy_skill_set "$HOME/.agents/skills"
fi

if [[ "$TARGET_ANTIGRAVITY" == 1 ]]; then
  configure_antigravity
  [[ "$STATUSLINE" == 1 ]] && configure_antigravity_statusline
fi

if [[ "$CENTAURY" == 1 ]]; then
  configure_centaury_guard
fi

printf 'statusline=%s\ncaveman=%s\nponytail=%s\n' \
  "$([[ "$STATUSLINE" == 1 ]] && printf enabled || printf disabled)" \
  "$([[ "$CAVEMAN_ALWAYS" == 1 ]] && printf wenyan-ultra || printf off)" \
  "$([[ "$PONYTAIL_ALWAYS" == 1 ]] && printf full || printf off)" >"$CONFIG_HOME/modes"

if [[ "$TARGET_CODEX" == 1 ]]; then
  sed "s|@STATUS_COMMAND@|$BIN_DIR/aicli-ultimate-status|g" \
    "$ROOT/statusline/tmux.conf" >"$CONFIG_HOME/tmux.conf"
  install_owned_file "$ROOT/statusline/codex-powerline" "$BIN_DIR/aicli-ultimate"
  install_owned_file "$ROOT/statusline/codex-powerline-status" "$BIN_DIR/aicli-ultimate-status"
fi

configure_shell

if [[ "$STATUSLINE" == 1 && "$TARGET_CODEX" == 1 ]]; then
  missing=()
  for command in tmux jq sqlite3 git; do command -v "$command" >/dev/null || missing+=("$command"); done
  if ((${#missing[@]})); then
    warn "Statusline dependencies missing: ${missing[*]}. Install them, or rerun and disable the statusline."
  fi
fi

if [[ "$STATUSLINE" == 1 && "$TARGET_CLAUDE" == 1 ]] && ! command -v jq >/dev/null; then
  warn "Claude statusline requires jq. Claude Code will ignore output until jq is installed."
fi

if [[ "$STATUSLINE" == 1 && "$TARGET_ANTIGRAVITY" == 1 ]] && ! command -v jq >/dev/null; then
  warn "Antigravity statusline requires jq; Antigravity will ignore output until jq is installed."
fi

if [[ "$DRY_RUN" != 1 && "$TARGET_CODEX" == 1 ]]; then
  marketplace_list="$(codex plugin marketplace list 2>/dev/null || true)"
  if ! awk '{print $1}' <<<"$marketplace_list" | grep -qx aicli-ultimate; then
    codex plugin marketplace add "$INSTALL_DIR"
  fi
  if [[ "$CAVEMAN" == 1 ]]; then install_plugin caveman@aicli-ultimate; fi
  if [[ "$PONYTAIL" == 1 ]]; then install_plugin ponytail@aicli-ultimate; fi
  if [[ "$CENTAURY" == 1 ]]; then install_plugin centaury-workflow@aicli-ultimate; fi
  if [[ "$SUPERPOWERS" == 1 ]]; then install_plugin superpowers@openai-curated 0; fi
  if [[ "$SECURITY" == 1 ]]; then install_plugin codex-security@openai-curated 0; fi
fi

if [[ "$DRY_RUN" != 1 ]]; then
  if [[ "$FRONTEND" == 1 ]]; then npx skills add anthropics/skills@frontend-design -g -y; fi
  if [[ "$PLAYWRIGHT" == 1 ]]; then npx skills add microsoft/playwright-cli@playwright-cli -g -y; fi
  if [[ "$REACT" == 1 ]]; then npx skills add vercel-labs/agent-skills@vercel-react-best-practices -g -y; fi
fi

cat >"$STATE_FILE" <<EOF
{
  "version": 1,
  "installed_at": "$timestamp",
  "backup": "$backup",
  "install_dir": "$INSTALL_DIR",
  "targets": "${AICLI_ULTIMATE_TARGETS:-interactive}",
  "centaury_guard": $([[ "$CENTAURY" == 1 ]] && printf true || printf false)
}
EOF

printf '\n\033[1;32mAI CLI Ultimate installed.\033[0m\n'
printf 'Restart your shell, then launch any configured agent.\n'
printf 'Skills are available through each agent native skill syntax or natural language.\n'
[[ "$CENTAURY" == 1 ]] && printf 'CentauryAI repositories now block direct commits and pushes to protected branches.\n'
