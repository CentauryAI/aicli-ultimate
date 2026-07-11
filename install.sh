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
MCPLS_VERSION="0.3.7"
GITHUB_LSP_VERSION="24.03.10"
HCOM_VERSION="0.7.23"
HCOM_INSTALLER_SHA256="5834dee99af05a039a259a81c43335913ec68920c627ead4cae638c652f649b2"
HCOM_INSTALLER_URL="https://github.com/aannoo/hcom/releases/download/v$HCOM_VERSION/hcom-installer.sh"
HCOM_BIN=""
TEMP_DIR=""

cleanup() {
  [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  return 0
}
trap cleanup EXIT

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

STEP_NUM=0
STEP_TOTAL=8
step() {
  STEP_NUM=$((STEP_NUM + 1))
  local width=24 filled
  filled=$((STEP_NUM * width / STEP_TOTAL))
  printf '\n\033[1;36m[%d/%d]\033[0m [%s%s] \033[1m%s\033[0m\n' \
    "$STEP_NUM" "$STEP_TOTAL" \
    "$(printf '%*s' "$filled" '' | tr ' ' '#')" \
    "$(printf '%*s' "$((width - filled))" '')" \
    "$*"
}

# skills(1) agent ids for the CLIs selected in this install (no exclude flag
# exists, so we allow-list; this also keeps optional skills out of unrelated
# agents and avoids the PromptScript "no global install" error).
skills_agents() {
  local a=()
  [[ "$TARGET_CODEX" == 1 ]] && a+=(codex)
  [[ "$TARGET_CLAUDE" == 1 ]] && a+=(claude-code)
  [[ "$TARGET_OPENCODE" == 1 ]] && a+=(opencode)
  [[ "$TARGET_OMP" == 1 ]] && a+=(pi)
  [[ "$TARGET_ANTIGRAVITY" == 1 ]] && a+=(antigravity-cli)
  printf '%s' "${a[*]}"
}

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
  local release_url
  if [[ "$REF" == main ]]; then
    release_url="https://github.com/$REPO_SLUG/releases/latest/download/aicli-ultimate.tar.gz"
  else
    release_url="https://github.com/$REPO_SLUG/releases/download/$REF/aicli-ultimate.tar.gz"
  fi
  info "Downloading $REPO_SLUG ($REF)" >&2
  if ! curl -fsSL "$release_url" | tar -xz -C "$TEMP_DIR" --strip-components=1; then
    info "Release bundle unavailable; falling back to branch $REF" >&2
    curl -fsSL "https://github.com/$REPO_SLUG/archive/refs/heads/$REF.tar.gz" \
      | tar -xz -C "$TEMP_DIR" --strip-components=1
  fi
  ROOT="$TEMP_DIR"
}

install_codex_if_missing() {
  command -v codex >/dev/null 2>&1 && return
  ask "Codex CLI is missing. Install @openai/codex with npm?" y || die "Codex CLI is required"
  command -v npm >/dev/null || die "npm is required to install Codex automatically"
  [[ "$DRY_RUN" == 1 ]] || npm install -g @openai/codex
}

install_hcom_if_missing() {
  local installer candidate
  if command -v hcom >/dev/null 2>&1; then
    HCOM_BIN="$(command -v hcom)"
    return 0
  fi
  [[ "$DRY_RUN" != 1 ]] || return 0
  command -v curl >/dev/null 2>&1 || die "curl is required to install hcom"
  installer="$(mktemp "${TMPDIR:-/tmp}/hcom-installer.XXXXXX")"
  if ! curl -fsSL "$HCOM_INSTALLER_URL" -o "$installer"; then
    rm -f "$installer"
    die "failed to download the official hcom installer"
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$HCOM_INSTALLER_SHA256" "$installer" | sha256sum -c - >/dev/null \
      || { rm -f "$installer"; die "hcom installer checksum verification failed"; }
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "$HCOM_INSTALLER_SHA256" "$installer" | shasum -a 256 -c - >/dev/null \
      || { rm -f "$installer"; die "hcom installer checksum verification failed"; }
  else
    rm -f "$installer"
    die "no SHA-256 utility found; refusing to run the hcom installer"
  fi
  if ! sh "$installer"; then
    rm -f "$installer"
    die "failed to install hcom"
  fi
  rm -f "$installer"
  for candidate in "$BIN_DIR/hcom" "$HOME/.local/bin/hcom" "$HOME/.cargo/bin/hcom"; do
    if [[ -x "$candidate" ]]; then
      HCOM_BIN="$candidate"
      return 0
    fi
  done
  command -v hcom >/dev/null 2>&1 && HCOM_BIN="$(command -v hcom)"
  [[ -n "$HCOM_BIN" ]] || die "hcom installed, but its binary was not found"
}

hcom_hook_installed() {
  local tool="$1"
  "$HCOM_BIN" status --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(bool(json.load(sys.stdin).get("tools", {}).get(sys.argv[1], {}).get("hooks")))
except (OSError, ValueError, TypeError):
    print(False)
' "$tool" | grep -qx True
}

configure_hcom() {
  local tool enabled marker_dir="$CONFIG_HOME/hcom-hooks"
  [[ "$ORQUESTRATOR" == 1 && "$DRY_RUN" != 1 ]] || return 0
  install_hcom_if_missing
  mkdir -p "$marker_dir"
  for tool in codex claude opencode omp antigravity; do
    case "$tool" in
      codex) enabled="$TARGET_CODEX" ;;
      claude) enabled="$TARGET_CLAUDE" ;;
      opencode) enabled="$TARGET_OPENCODE" ;;
      omp) enabled="$TARGET_OMP" ;;
      antigravity) enabled="$TARGET_ANTIGRAVITY" ;;
    esac
    [[ "$enabled" == 1 ]] || continue
    if hcom_hook_installed "$tool"; then
      info "HCOM hooks already installed: $tool"
    elif "$HCOM_BIN" hooks add "$tool"; then
      touch "$marker_dir/$tool"
    else
      warn "Could not install HCOM hooks for $tool; use hcom start for ad-hoc mode."
    fi
  done
}

report_orquestrator() {
  [[ "$ORQUESTRATOR" == 1 && "$DRY_RUN" != 1 ]] || return 0
  info "Orquestrator (HCOM) install check:"
  local tool enabled skilldir hook skill
  for tool in codex claude opencode omp antigravity; do
    case "$tool" in
      codex) enabled="$TARGET_CODEX"; skilldir="" ;;
      claude) enabled="$TARGET_CLAUDE"; skilldir="$HOME/.claude/skills/orquestrator-hcom" ;;
      opencode) enabled="$TARGET_OPENCODE"; skilldir="$HOME/.agents/skills/orquestrator-hcom" ;;
      omp) enabled="$TARGET_OMP"; skilldir="$HOME/.agents/skills/orquestrator-hcom" ;;
      antigravity) enabled="$TARGET_ANTIGRAVITY"
        skilldir="$HOME/.gemini/config/plugins/aicli-ultimate/skills/orquestrator-hcom" ;;
    esac
    [[ "$enabled" == 1 ]] || continue
    hcom_hook_installed "$tool" && hook="✓" || hook="✗"
    if [[ -z "$skilldir" ]]; then
      skill="native plugin"
    elif [[ -d "$skilldir" ]]; then
      skill="✓"
    else
      skill="✗"
    fi
    printf '  %-12s hook %s   skill %s\n' "$tool" "$hook" "$skill"
  done
}

backup_file() {
  local file="$1" backup="$2"
  [[ -e "$file" ]] || return 0
  mkdir -p "$backup/$(dirname "${file#$HOME/}")"
  cp -a "$file" "$backup/${file#$HOME/}"
}

render_agents() {
  local source="$1" target="$2" caveman_rule="" ponytail_rule="" lsp_rule=""
  [[ "$CAVEMAN_ALWAYS" == 1 ]] && caveman_rule='- Keep Caveman output mode active: terse output with full technical substance. Disable only when the user says “stop caveman”.'
  [[ "$PONYTAIL_ALWAYS" == 1 ]] && ponytail_rule='- Keep Ponytail engineering mode active: YAGNI, standard library first, native features before dependencies, and the smallest correct implementation.'
  [[ "$LSP" == 1 ]] && lsp_rule='- Prefer native LSP tools for symbol navigation and focused diagnostics when available; fall back to rg and repository checks, and avoid dumping workspace-wide output.'
  sed \
    -e "s|@CAVEMAN_RULE@|$caveman_rule|" \
    -e "s|@PONYTAIL_RULE@|$ponytail_rule|" \
    -e "s|@LSP_RULE@|$lsp_rule|" \
    "$source" >"$target"
}

install_language_servers() {
  local packages=()
  [[ "$LSP" == 1 && "$DRY_RUN" != 1 ]] || return 0

  if ! command -v rust-analyzer >/dev/null 2>&1; then
    if command -v rustup >/dev/null 2>&1; then
      rustup component add rust-analyzer \
        || warn "Could not install rust-analyzer with rustup."
    else
      warn "rust-analyzer is missing and rustup is unavailable."
    fi
  fi

  if ! command -v typescript-language-server >/dev/null 2>&1 \
    || ! command -v tsc >/dev/null 2>&1; then
    packages+=(typescript-language-server typescript)
  fi
  command -v pyright-langserver >/dev/null 2>&1 || packages+=(pyright)

  if ((${#packages[@]})); then
    if command -v npm >/dev/null 2>&1; then
      npm install -g "${packages[@]}" \
        || warn "Could not install Node language servers: ${packages[*]}."
    else
      warn "npm is unavailable; missing Node language servers: ${packages[*]}."
    fi
  fi

  install_github_lsp

  if [[ "$TARGET_CODEX" == 1 || "$TARGET_ANTIGRAVITY" == 1 ]]; then
    install_mcpls
  fi
}

install_github_lsp() {
  local os arch platform asset checksum server_tmp archive marker
  marker="$GITHUB_LSP_BIN.aicli-ultimate-owned"
  if [[ -x "$GITHUB_LSP_BIN" && -f "$marker" ]]; then
    [[ "$(cat "$marker")" == "$GITHUB_LSP_VERSION" ]] && return 0
  elif command -v github-lsp >/dev/null 2>&1; then
    return 0
  fi
  command -v curl >/dev/null 2>&1 || { warn "github-lsp requires curl; GitHub Markdown LSP was not installed."; return; }
  command -v tar >/dev/null 2>&1 || { warn "github-lsp requires tar with xz support; GitHub Markdown LSP was not installed."; return; }

  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os:$arch" in
    Linux:x86_64|Linux:amd64)
      platform=x86_64-linux
      checksum=c06cf4e13d83f4a7712ba5e76ec8d319a14351d0417deb86b1f1782e8327bc0d
      ;;
    Linux:aarch64|Linux:arm64)
      platform=aarch64-linux
      checksum=f85e64ce3d8d9447da06379cec38c41f601d11758cf336757d1d09955b1a9024
      ;;
    Darwin:x86_64|Darwin:amd64)
      platform=x86_64-macos
      checksum=127431ba1fcd44c238c6e858071d4be5271d0d1932fa6d176234df115930e046
      ;;
    Darwin:aarch64|Darwin:arm64)
      platform=aarch64-macos
      checksum=4016c3e613d6adc527129632d9f2e55238924049b714bfb9b5ae98afc3427c66
      ;;
    *) warn "github-lsp has no supported binary for $os/$arch; GitHub Markdown LSP was not installed."; return ;;
  esac

  asset="github-lsp-$GITHUB_LSP_VERSION-$platform.tar.xz"
  server_tmp="$(mktemp -d "${TMPDIR:-/tmp}/aicli-github-lsp.XXXXXX")"
  archive="$server_tmp/$asset"
  if ! curl -fsSL "https://github.com/github-language-server/github-lsp/releases/download/$GITHUB_LSP_VERSION/$asset" -o "$archive"; then
    rm -rf "$server_tmp"
    warn "Could not download github-lsp $GITHUB_LSP_VERSION."
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$server_tmp" && printf '%s  %s\n' "$checksum" "$asset" | sha256sum -c - >/dev/null) \
      || { rm -rf "$server_tmp"; warn "github-lsp checksum verification failed."; return; }
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$server_tmp" && printf '%s  %s\n' "$checksum" "$asset" | shasum -a 256 -c - >/dev/null) \
      || { rm -rf "$server_tmp"; warn "github-lsp checksum verification failed."; return; }
  else
    rm -rf "$server_tmp"
    warn "No SHA-256 utility found; refusing to install github-lsp without verification."
    return
  fi
  if tar -xJf "$archive" -C "$server_tmp" --strip-components=1 \
    && [[ -f "$server_tmp/github-lsp" ]]; then
    install_owned_file "$server_tmp/github-lsp" "$GITHUB_LSP_BIN"
    if [[ -f "$marker" ]]; then
      chmod +x "$GITHUB_LSP_BIN"
      printf '%s\n' "$GITHUB_LSP_VERSION" >"$marker"
    else
      warn "Keeping existing unowned github-lsp path without changing its permissions: $GITHUB_LSP_BIN"
    fi
  else
    warn "Could not extract github-lsp $GITHUB_LSP_VERSION."
  fi
  rm -rf "$server_tmp"
}

install_mcpls() {
  local os arch target asset checksum bridge_tmp archive
  if [[ -x "$MCPLS_BIN" && -f "$MCPLS_BIN.aicli-ultimate-owned" ]] \
    && "$MCPLS_BIN" --version 2>/dev/null | grep -Eq "^mcpls ${MCPLS_VERSION}([[:space:]]|$)"; then
    return 0
  fi
  command -v curl >/dev/null 2>&1 || { warn "mcpls requires curl; Codex/Antigravity LSP bridge was not installed."; return; }
  command -v tar >/dev/null 2>&1 || { warn "mcpls requires tar; Codex/Antigravity LSP bridge was not installed."; return; }

  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os:$arch" in
    Linux:x86_64|Linux:amd64)
      target=x86_64-unknown-linux-gnu
      checksum=40e88e46d9b6f812a146f6aa0304a8e6c47e98a7a767f53e249bff714814ed92
      ;;
    Linux:aarch64|Linux:arm64)
      target=aarch64-unknown-linux-gnu
      checksum=c2d235fc081defce7e934c96eef83142f3f26f16eca78e3a651c4b5775f843d1
      ;;
    Darwin:x86_64|Darwin:amd64)
      target=x86_64-apple-darwin
      checksum=763efe9005f758dc6c28f409c8b6ba7144808e40e2d907e4f7a36d5ad68d530e
      ;;
    Darwin:aarch64|Darwin:arm64)
      target=aarch64-apple-darwin
      checksum=b2e863acdf838d97ade7185a81b9bbdd03715160a668e5e6e27e694a6145b264
      ;;
    *) warn "mcpls has no supported binary for $os/$arch; Codex/Antigravity LSP bridge was not installed."; return ;;
  esac

  asset="mcpls-$target.tar.gz"
  bridge_tmp="$(mktemp -d "${TMPDIR:-/tmp}/aicli-mcpls.XXXXXX")"
  archive="$bridge_tmp/$asset"
  if ! curl -fsSL "https://github.com/bug-ops/mcpls/releases/download/v$MCPLS_VERSION/$asset" -o "$archive"; then
    rm -rf "$bridge_tmp"
    warn "Could not download mcpls v$MCPLS_VERSION."
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$bridge_tmp" && printf '%s  %s\n' "$checksum" "$asset" | sha256sum -c - >/dev/null) \
      || { rm -rf "$bridge_tmp"; warn "mcpls checksum verification failed."; return; }
  elif command -v shasum >/dev/null 2>&1; then
    (cd "$bridge_tmp" && printf '%s  %s\n' "$checksum" "$asset" | shasum -a 256 -c - >/dev/null) \
      || { rm -rf "$bridge_tmp"; warn "mcpls checksum verification failed."; return; }
  else
    rm -rf "$bridge_tmp"
    warn "No SHA-256 utility found; refusing to install mcpls without verification."
    return
  fi
  if tar -xzf "$archive" -C "$bridge_tmp" && [[ -f "$bridge_tmp/mcpls" ]]; then
    install_owned_file "$bridge_tmp/mcpls" "$MCPLS_BIN"
    if [[ -f "$MCPLS_BIN.aicli-ultimate-owned" ]]; then
      chmod +x "$MCPLS_BIN"
    else
      warn "Keeping existing unowned mcpls path without changing its permissions: $MCPLS_BIN"
    fi
  else
    warn "Could not extract mcpls v$MCPLS_VERSION."
  fi
  rm -rf "$bridge_tmp"
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
    printf 'export PATH="%s:$PATH"\n' "$BIN_DIR"
    [[ "$TARGET_OPENCODE" == 1 && "$LSP" == 1 ]] \
      && printf 'export OPENCODE_EXPERIMENTAL_LSP_TOOL=true\n'
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
  copy_skill_source "$target" "$ROOT/plugins/apollo-rust-best-practices/skills"
  if [[ "$CAVEMAN" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/caveman/skills"; fi
  if [[ "$PONYTAIL" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/ponytail/skills"; fi
  if [[ "$CENTAURY" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/centaury-workflow/skills"; fi
  if [[ "$ORQUESTRATOR" == 1 ]]; then copy_skill_source "$target" "$ROOT/plugins/orquestrator/skills"; fi
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
  backup_skill_source "$target" "$backup" "$ROOT/plugins/apollo-rust-best-practices/skills"
  if [[ "$CAVEMAN" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/caveman/skills"; fi
  if [[ "$PONYTAIL" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/ponytail/skills"; fi
  if [[ "$CENTAURY" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/centaury-workflow/skills"; fi
  if [[ "$ORQUESTRATOR" == 1 ]]; then backup_skill_source "$target" "$backup" "$ROOT/plugins/orquestrator/skills"; fi
}

configure_antigravity() {
  local target="$HOME/.gemini/config/plugins/aicli-ultimate" stage_root stage previous
  if [[ -e "$target" && ! -e "$target/.aicli-ultimate-owned" ]]; then
    warn "Keeping existing Antigravity plugin: $target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  stage_root="$(mktemp -d "${TMPDIR:-/tmp}/aicli-antigravity.XXXXXX")"
  stage="$stage_root/aicli-ultimate"
  mkdir -p "$stage/rules"
  touch "$stage/.aicli-ultimate-owned"
  cp "$ROOT/adapters/antigravity/plugin.json" "$stage/plugin.json"
  if [[ "$LSP" == 1 && "$BRIDGE_READY" == 1 ]]; then
    sed \
      -e "s|@MCPLS_BIN@|$MCPLS_BIN|g" \
      -e "s|@MCPLS_CONFIG@|$CONFIG_HOME/mcpls.toml|g" \
      "$ROOT/adapters/antigravity/mcp_config.json" >"$stage/mcp_config.json"
  fi
  cp "$CONFIG_HOME/global-instructions.md" "$stage/rules/global.md"
  copy_skill_set "$stage/skills"

  if [[ "$DRY_RUN" != 1 ]] && command -v agy >/dev/null 2>&1; then
    if ! agy plugin validate "$stage" >/dev/null; then
      rm -rf "$stage_root"
      warn "Antigravity rejected the generated plugin; keeping the previous installation."
      return 0
    fi
    previous="$stage_root/previous"
    [[ -e "$target" ]] && mv "$target" "$previous"
    if ! agy plugin install "$stage" >/dev/null; then
      rm -rf "$target"
      if [[ -e "$previous" ]]; then
        mv "$previous" "$target"
        warn "Antigravity could not register the generated plugin; restored the previous installation."
      else
        cp -R "$stage" "$target"
        warn "Antigravity could not register the generated plugin; copied it for inspection."
      fi
    fi
  else
    rm -rf "$target"
    cp -R "$stage" "$target"
  fi
  rm -rf "$stage_root"
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
  local settings="$HOME/.gemini/antigravity-cli/settings.json" status_json legacy_json state
  state="$CONFIG_HOME/antigravity-statusline-previous.json"
  legacy_json="$(python3 -c 'import json,sys; print(json.dumps({"command":sys.argv[1],"enabled":True,"stack_with_default":False}))' "$BIN_DIR/antigravity-ultimate-status")"
  status_json="$(python3 -c 'import json,sys; print(json.dumps({"type":"","command":sys.argv[1],"enabled":True}))' "$BIN_DIR/antigravity-ultimate-status")"
  python3 "$ROOT/scripts/json_override.py" migrate "$settings" statusLine \
    "$legacy_json" "$status_json" "$state"
  if python3 "$ROOT/scripts/json_override.py" set "$settings" statusLine \
    "$status_json" "$state"; then
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
  local plugin="$1" required="${2:-1}" ownership_marker="${3:-}" plugin_list
  plugin_list="$(codex plugin list 2>/dev/null || true)"
  if grep -Eq "^${plugin//./\.}[[:space:]]+installed" <<<"$plugin_list"; then
    info "Plugin already installed: $plugin"
  elif ! codex plugin add "$plugin"; then
    if [[ "$required" == 1 ]]; then
      die "failed to install required plugin: $plugin"
    fi
    warn "Optional plugin unavailable: $plugin"
  elif [[ -n "$ownership_marker" ]]; then
    mkdir -p "$(dirname "$ownership_marker")"
    touch "$ownership_marker"
  fi
}

claude_plugin_state() {
  local plugin="$1" plugin_json
  if ! plugin_json="$(claude plugin list --json 2>/dev/null)"; then
    printf 'query-failed\n'
    return 0
  fi
  python3 -c '
import json, sys
plugin = sys.argv[1]
try:
    item = next((item for item in json.load(sys.stdin) if item.get("id") == plugin), None)
    print("absent" if item is None else ("enabled" if item.get("enabled") else "disabled"))
except (ValueError, StopIteration):
    print("query-failed")
' "$plugin" <<<"$plugin_json"
}

install_claude_plugin() {
  local source="$1" marketplace="$2" plugin="$3" state marker_dir="$CONFIG_HOME/native-plugins"
  command -v claude >/dev/null 2>&1 || return 0
  mkdir -p "$marker_dir"
  state="$(claude_plugin_state "$plugin")"
  if [[ "$state" == query-failed ]]; then
    warn "Could not inspect Claude plugins; keeping existing state for $plugin."
    return 0
  elif [[ "$state" == absent ]]; then
    if ! claude plugin marketplace list 2>/dev/null | grep -Eq "^[[:space:]]*❯[[:space:]]+$marketplace$"; then
      claude plugin marketplace add "$source" || { warn "Could not add Claude marketplace: $source"; return; }
      touch "$marker_dir/claude-marketplace-$marketplace"
    fi
    claude plugin install "$plugin" || { warn "Could not install Claude plugin: $plugin"; return; }
    touch "$marker_dir/claude-installed-${plugin%@*}"
  elif [[ "$state" == disabled ]]; then
    claude plugin enable "$plugin" || { warn "Could not enable Claude plugin: $plugin"; return; }
    touch "$marker_dir/claude-enabled-${plugin%@*}"
  else
    info "Claude plugin already enabled: $plugin"
  fi
}

omp_plugin_installed() {
  local plugin="$1"
  omp plugin list --json 2>/dev/null | python3 -c '
import json, sys
try:
    print(any(item.get("name") == sys.argv[1] for item in json.load(sys.stdin).get("npm", [])))
except ValueError:
    print(False)
' "$plugin" | grep -qx True
}

antigravity_plugin_installed() {
  local plugin="$1"
  agy plugin list 2>/dev/null | python3 -c '
import json, sys
try:
    print(any(item.get("name") == sys.argv[1] for item in json.load(sys.stdin).get("imports", [])))
except ValueError:
    print(False)
' "$plugin" | grep -qx True
}

json_array_contains() {
  local file="$1" key="$2" value_json="$3"
  python3 -c '
import json, pathlib, sys
path, key, raw = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
try:
    data = json.loads(path.read_text()) if path.exists() else {}
    print(json.loads(raw) in data.get(key, []))
except (OSError, ValueError, TypeError):
    print(False)
' "$file" "$key" "$value_json" | grep -qx True
}

install_native_mode_plugins() {
  local marker_dir="$CONFIG_HOME/native-plugins"
  [[ "$DRY_RUN" == 1 ]] && return 0
  mkdir -p "$marker_dir"

  if [[ "$TARGET_CLAUDE" == 1 ]]; then
    [[ "$CAVEMAN" == 1 ]] && install_claude_plugin JuliusBrussee/caveman caveman caveman@caveman
    [[ "$PONYTAIL" == 1 ]] && install_claude_plugin DietrichGebert/ponytail ponytail ponytail@ponytail
    if [[ "$LSP" == 1 ]]; then
      install_claude_plugin anthropics/claude-plugins-official claude-plugins-official rust-analyzer-lsp@claude-plugins-official
      install_claude_plugin anthropics/claude-plugins-official claude-plugins-official typescript-lsp@claude-plugins-official
      install_claude_plugin anthropics/claude-plugins-official claude-plugins-official pyright-lsp@claude-plugins-official
      [[ "$GITHUB_LSP_READY" == 1 ]] \
        && install_claude_plugin "$INSTALL_DIR" aicli-ultimate github-lsp@aicli-ultimate
    fi
  fi

  if [[ "$TARGET_OMP" == 1 && "$PONYTAIL" == 1 ]] && command -v omp >/dev/null 2>&1 \
    && ! omp_plugin_installed @dietrichgebert/ponytail; then
    if omp plugin install @dietrichgebert/ponytail; then
      touch "$marker_dir/omp-ponytail"
    else
      warn "Could not install Ponytail's native OMP plugin. Shared skills remain available."
    fi
  fi

  if [[ "$TARGET_ANTIGRAVITY" == 1 ]] && command -v agy >/dev/null 2>&1; then
    if [[ "$CAVEMAN" == 1 ]] && ! antigravity_plugin_installed caveman; then
      agy plugin install https://github.com/JuliusBrussee/caveman \
        && touch "$marker_dir/antigravity-caveman" \
        || warn "Could not install Caveman's Antigravity plugin. Shared skills remain available."
    fi
    if [[ "$PONYTAIL" == 1 ]] && ! antigravity_plugin_installed ponytail; then
      agy plugin install https://github.com/DietrichGebert/ponytail \
        && touch "$marker_dir/antigravity-ponytail" \
        || warn "Could not install Ponytail's Antigravity plugin. Shared skills remain available."
    fi
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
if [[ -n "${AICLI_ULTIMATE_LSP:-}" ]]; then
  [[ "$AICLI_ULTIMATE_LSP" =~ ^[01]$ ]] || die "AICLI_ULTIMATE_LSP must be 0 or 1"
  LSP="$AICLI_ULTIMATE_LSP"
else
  ask "Install essential LSP support (Rust, TypeScript/JavaScript, Python, and GitHub Markdown)?" y && LSP=1 || LSP=0
fi
MCPLS_BIN="$BIN_DIR/aicli-mcpls"
GITHUB_LSP_BIN="$BIN_DIR/github-lsp"
ask "Install the Caveman plugin?" y && CAVEMAN=1 || CAVEMAN=0
if [[ "$CAVEMAN" == 1 ]] && ask "Keep Caveman active by default?" y; then CAVEMAN_ALWAYS=1; else CAVEMAN_ALWAYS=0; fi
ask "Install the Ponytail plugin?" y && PONYTAIL=1 || PONYTAIL=0
if [[ "$PONYTAIL" == 1 ]] && ask "Keep Ponytail active by default?" y; then PONYTAIL_ALWAYS=1; else PONYTAIL_ALWAYS=0; fi
ask "Install HCOM Orquestrator mode?" y && ORQUESTRATOR=1 || ORQUESTRATOR=0
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
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/package.json" "$HOME/AGENTS.md" \
  "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/config.yml" \
  "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/lsp.json" \
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

step "Installing files"
mkdir -p "$INSTALL_DIR" "$CONFIG_HOME" "$BIN_DIR"
if [[ "$ROOT" != "$INSTALL_DIR" ]]; then
  (cd "$ROOT" && tar --exclude=.git -cf - .) | (cd "$INSTALL_DIR" && tar -xf -)
fi

render_agents "$ROOT/config/AGENTS.md" "$CONFIG_HOME/global-instructions.md"

if [[ "$LSP" == 1 && ( "$TARGET_CODEX" == 1 || "$TARGET_ANTIGRAVITY" == 1 ) ]]; then
  install_owned_file "$ROOT/config/mcpls.toml" "$CONFIG_HOME/mcpls.toml"
fi
step "Language servers"
install_language_servers
if [[ "$LSP" == 1 ]] && { [[ "$DRY_RUN" == 1 ]] \
  || { [[ -x "$MCPLS_BIN" && -f "$MCPLS_BIN.aicli-ultimate-owned" ]] \
    && "$MCPLS_BIN" --version 2>/dev/null | grep -Eq "^mcpls ${MCPLS_VERSION}([[:space:]]|$)"; }; }; then
  BRIDGE_READY=1
else
  BRIDGE_READY=0
fi
if [[ "$LSP" == 1 ]] && { [[ "$DRY_RUN" == 1 ]] \
  || command -v github-lsp >/dev/null 2>&1 || [[ -x "$GITHUB_LSP_BIN" ]]; }; then
  GITHUB_LSP_READY=1
else
  GITHUB_LSP_READY=0
fi
if [[ "$GITHUB_LSP_READY" == 1 && "$DRY_RUN" != 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    warn "github-lsp requires the gh CLI; install and authenticate gh before use."
  elif ! gh auth status >/dev/null 2>&1; then
    warn "github-lsp requires an authenticated gh CLI; run: gh auth login"
  fi
fi

step "Configuring agents"
if [[ "$TARGET_CODEX" == 1 ]]; then
  mkdir -p "$CODEX_HOME/agents" "$CODEX_HOME/themes"
  status_value='status_line = ["model-with-reasoning", "current-dir", "git-branch", "context-remaining", "five-hour-limit", "weekly-limit"]'
  [[ "$STATUSLINE" == 1 ]] && status_value='# Native status line disabled; external Powerline wrapper is active.'
  [[ "$LSP" == 1 && "$BRIDGE_READY" == 1 ]] && lsp_enabled=true || lsp_enabled=false
  sed \
    -e "s|@EFFORT@|$EFFORT|" \
    -e "s|@CODEX_HOME@|$CODEX_HOME|g" \
    -e "s|@MCPLS_BIN@|$MCPLS_BIN|g" \
    -e "s|@MCPLS_CONFIG@|$CONFIG_HOME/mcpls.toml|g" \
    -e "s|@LSP_ENABLED@|$lsp_enabled|g" \
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
  if [[ "$LSP" == 1 ]]; then
    github_lsp_json='{"command":["github-lsp"],"extensions":[".md",".markdown"]}'
    if [[ "$GITHUB_LSP_READY" == 1 ]]; then
      python3 "$ROOT/scripts/json_lsp.py" add "$opencode_home/opencode.json" github-lsp \
        "$github_lsp_json" "$CONFIG_HOME/opencode-github-lsp-state.json" \
        || warn "Keeping the existing OpenCode LSP configuration."
    else
      python3 "$ROOT/scripts/json_add.py" "$opencode_home/opencode.json" lsp true \
        "$CONFIG_HOME/opencode-lsp-owned" \
        || warn "Keeping the existing OpenCode LSP configuration."
    fi
    python3 "$ROOT/scripts/json_add.py" "$opencode_home/opencode.json" permission.lsp '"allow"' \
      "$CONFIG_HOME/opencode-lsp-permission-owned" \
      || warn "Keeping the existing OpenCode LSP permission."
  fi
  if [[ "$PONYTAIL" == 1 ]]; then
    if ! json_array_contains "$opencode_home/opencode.json" plugin '"@dietrichgebert/ponytail"'; then
      python3 "$ROOT/scripts/json_array.py" add "$opencode_home/opencode.json" plugin '"@dietrichgebert/ponytail"'
      touch "$CONFIG_HOME/opencode-ponytail-owned"
    fi
  fi
  [[ "$STATUSLINE" == 1 ]] && configure_opencode_statusline "$opencode_home"
fi

if [[ "$TARGET_OMP" == 1 ]]; then
  upsert_managed_block "$HOME/AGENTS.md" "$CONFIG_HOME/global-instructions.md"
  if [[ "$LSP" == 1 && "$GITHUB_LSP_READY" == 1 ]]; then
    omp_lsp_json='{"command":"github-lsp","args":[],"fileTypes":[".md",".markdown"],"rootMarkers":[".git"]}'
    python3 "$ROOT/scripts/json_object_add.py" \
      "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/lsp.json" servers github-lsp \
      "$omp_lsp_json" "$CONFIG_HOME/omp-github-lsp-owned" \
      || warn "Keeping the existing OMP github-lsp configuration."
  fi
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

step "Native mode plugins"
install_native_mode_plugins
step "Orquestrator (HCOM)"
configure_hcom
report_orquestrator

printf 'statusline=%s\nlsp=%s\ncaveman=%s\nponytail=%s\n' \
  "$([[ "$STATUSLINE" == 1 ]] && printf enabled || printf disabled)" \
  "$([[ "$LSP" == 1 ]] && printf enabled || printf disabled)" \
  "$([[ "$CAVEMAN_ALWAYS" == 1 ]] && printf wenyan-ultra || printf off)" \
  "$([[ "$PONYTAIL_ALWAYS" == 1 ]] && printf full || printf off)" >"$CONFIG_HOME/modes"

if [[ "$TARGET_CODEX" == 1 ]]; then
  sed "s|@STATUS_COMMAND@|$BIN_DIR/aicli-ultimate-status|g" \
    "$ROOT/statusline/tmux.conf" >"$CONFIG_HOME/tmux.conf"
  install_owned_file "$ROOT/statusline/codex-powerline" "$BIN_DIR/aicli-ultimate"
  install_owned_file "$ROOT/statusline/codex-powerline-status" "$BIN_DIR/aicli-ultimate-status"
fi

step "Shell integration"
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
  codex_marker_dir="$CONFIG_HOME/native-plugins"
  marketplace_list="$(codex plugin marketplace list 2>/dev/null || true)"
  if ! awk '{print $1}' <<<"$marketplace_list" | grep -qx aicli-ultimate; then
    codex plugin marketplace add "$INSTALL_DIR"
    mkdir -p "$codex_marker_dir"
    touch "$codex_marker_dir/codex-marketplace-aicli-ultimate"
  fi
  if [[ "$CAVEMAN" == 1 ]]; then install_plugin caveman@aicli-ultimate; fi
  if [[ "$PONYTAIL" == 1 ]]; then install_plugin ponytail@aicli-ultimate; fi
  if [[ "$CENTAURY" == 1 ]]; then install_plugin centaury-workflow@aicli-ultimate; fi
  if [[ "$ORQUESTRATOR" == 1 ]]; then install_plugin orquestrator@aicli-ultimate; fi
  install_plugin apollo-rust-best-practices@aicli-ultimate 1 \
    "$codex_marker_dir/codex-apollo-rust-best-practices"
  if [[ "$SUPERPOWERS" == 1 ]]; then install_plugin superpowers@openai-curated 0; fi
  if [[ "$SECURITY" == 1 ]]; then install_plugin codex-security@openai-curated 0; fi
fi

if [[ "$DRY_RUN" != 1 ]] && (( FRONTEND + PLAYWRIGHT + REACT > 0 )); then
  step "Optional skills"
  skills_agent_list="$(skills_agents)"
  install_optional_skill() {
    local ref="$1" name="$2"
    # shellcheck disable=SC2086 -- $skills_agent_list is a controlled space-separated allow-list
    if npx skills add "$ref" -g -y -a $skills_agent_list; then
      info "Installed optional skill: $name"
    else
      warn "Could not install optional skill: $name"
    fi
  }
  [[ "$FRONTEND" == 1 ]] && install_optional_skill anthropics/skills@frontend-design frontend-design
  [[ "$PLAYWRIGHT" == 1 ]] && install_optional_skill microsoft/playwright-cli@playwright-cli playwright-cli
  [[ "$REACT" == 1 ]] && install_optional_skill vercel-labs/agent-skills@vercel-react-best-practices vercel-react-best-practices
fi

step "Finalizing"
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
