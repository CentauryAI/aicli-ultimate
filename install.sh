#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="${AICLI_ULTIMATE_REPO:-CentauryAI/aicli-ultimate}"
REF="${AICLI_ULTIMATE_REF:-main}"
NONINTERACTIVE="${AICLI_ULTIMATE_NONINTERACTIVE:-0}"
OFFLINE="${AICLI_ULTIMATE_OFFLINE:-0}"
DRY_RUN="${AICLI_ULTIMATE_DRY_RUN:-0}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/aicli-ultimate"
INSTALL_DIR="${AICLI_ULTIMATE_INSTALL_DIR:-$HOME/.local/share/aicli-ultimate}"
BIN_DIR="${AICLI_ULTIMATE_BIN_DIR:-$HOME/.local/bin}"
STATE_FILE="$CONFIG_HOME/install-state.json"
CODEX_SHIM="$CONFIG_HOME/codex-bin/codex"
MCPLS_VERSION="0.3.7"
GITHUB_LSP_VERSION="24.03.10"
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
STEP_TOTAL=7
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

# Prefer the ratatui TUI (mouse support): prebuilt binary from the release,
# or a local cargo build. Empty TUI_BIN = whiptail fallback.
build_tui_bin() {
  [[ -f "$ROOT/tui/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1 || return 1
  info "Building the setup TUI (one-time cargo build)"
  cargo build --release --quiet --manifest-path "$ROOT/tui/Cargo.toml" 2>/dev/null \
    && [[ -x "$ROOT/tui/target/release/aicli-tui" ]] \
    && TUI_BIN="$ROOT/tui/target/release/aicli-tui"
}

resolve_tui_bin() {
  TUI_BIN=""
  local os arch url
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  # dev checkout: the local source is newer than any published binary
  if [[ -d "$ROOT/.git" ]] && build_tui_bin; then
    return
  fi
  if [[ "$OFFLINE" != 1 ]] && command -v curl >/dev/null 2>&1; then
    if [[ "$REF" == main ]]; then
      url="https://github.com/$REPO_SLUG/releases/latest/download/aicli-tui-$os-$arch"
    else
      url="https://github.com/$REPO_SLUG/releases/download/$REF/aicli-tui-$os-$arch"
    fi
    [[ -n "$TEMP_DIR" ]] || TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate.XXXXXX")"
    if curl -fsSL "$url" -o "$TEMP_DIR/aicli-tui" 2>/dev/null; then
      chmod +x "$TEMP_DIR/aicli-tui"
      TUI_BIN="$TEMP_DIR/aicli-tui"
      return
    fi
  fi
  build_tui_bin || true
}

# Single source of truth: checklist tag -> selection variable.
checklist_var() {
  case "$1" in
    codex) printf TARGET_CODEX ;;
    claude) printf TARGET_CLAUDE ;;
    opencode) printf TARGET_OPENCODE ;;
    omp) printf TARGET_OMP ;;
    antigravity) printf TARGET_ANTIGRAVITY ;;
    statusline) printf STATUSLINE ;;
    lsp) printf LSP ;;
    caveman) printf CAVEMAN ;;
    caveman-always) printf CAVEMAN_ALWAYS ;;
    ponytail) printf PONYTAIL ;;
    ponytail-always) printf PONYTAIL_ALWAYS ;;
    orquestrator) printf ORQUESTRATOR ;;
    superpowers) printf SUPERPOWERS ;;
    centaury) printf CENTAURY ;;
    completions) printf COMPLETIONS ;;
    security) printf SECURITY ;;
    frontend) printf FRONTEND ;;
    playwright) printf PLAYWRIGHT ;;
    react) printf REACT ;;
    webapp) printf WEBAPP ;;
    mcp-builder) printf MCPBUILDER ;;
    grill-with-docs) printf GRILLDOCS ;;
    security-bp) printf SECBP ;;
    diff-review) printf DIFFREVIEW ;;
    gh-fix-ci) printf GHFIXCI ;;
    *) return 1 ;;
  esac
}

# During an update, a previously selected feature whose bundled files changed
# in the new release is a forced update. Only bundle-shipped features are
# detectable; external plugins/skills are refreshed by their own managers.
feature_changed() {
  local paths=() p
  case "$1" in
    caveman) paths=(plugins/caveman) ;;
    ponytail) paths=(plugins/ponytail) ;;
    orquestrator) paths=(plugins/orquestrator) ;;
    centaury) paths=(plugins/centaury-workflow git-hooks) ;;
    statusline) paths=(statusline) ;;
    lsp) paths=(config/mcpls.toml plugins/github-lsp) ;;
    *) return 1 ;;
  esac
  [[ -d "$INSTALL_DIR" && "$ROOT" != "$INSTALL_DIR" ]] || return 1
  for p in "${paths[@]}"; do
    diff -rq "$INSTALL_DIR/$p" "$ROOT/$p" >/dev/null 2>&1 || return 0
  done
  return 1
}

run_tui() {
  local choices d_claude=OFF d_opencode=OFF d_omp=OFF d_agy=OFF
  command -v claude >/dev/null 2>&1 && d_claude=ON
  command -v opencode >/dev/null 2>&1 && d_opencode=ON
  command -v omp >/dev/null 2>&1 && d_omp=ON
  command -v agy >/dev/null 2>&1 && d_agy=ON
  local items=(
    codex "Configure Codex" ON
    claude "Configure Claude Code" "$d_claude"
    opencode "Configure OpenCode" "$d_opencode"
    omp "Configure OMP (Oh My Pi)" "$d_omp"
    antigravity "Configure Antigravity CLI (agy)" "$d_agy"
    statusline "Powerline statuslines" ON
    lsp "LSP support (Rust, TS/JS, Python, GitHub Markdown)" ON
    caveman "Caveman plugin" ON
    caveman-always "Keep Caveman active by default" ON
    ponytail "Ponytail plugin" ON
    ponytail-always "Keep Ponytail active by default" ON
    orquestrator "HCOM Orquestrator mode" ON
    superpowers "Official Superpowers plugin (Codex)" ON
    centaury "CentauryAI protected-branch workflow" ON
    completions "Shell completions" ON
    security "Official Codex Security plugin (Codex)" OFF
    frontend "Optional frontend skills" OFF
    playwright "Optional Playwright testing skill" OFF
    react "Optional React best-practices skill" OFF
    webapp "Optional web-app testing skill (Anthropic)" OFF
    mcp-builder "Optional MCP builder skill (Anthropic)" OFF
    grill-with-docs "Optional plan-grilling skill with ADR docs" OFF
    security-bp "Optional security best-practices skill (OpenAI)" OFF
    diff-review "Optional differential security review skill (Trail of Bits)" OFF
    gh-fix-ci "Optional GitHub Actions fixer skill (OpenAI)" OFF
  )
  # Update mode: pre-fill from the saved selections. Previously selected
  # features whose bundled files changed are locked as forced updates (TUI
  # only; whiptail cannot lock). New features default to unselected.
  if [[ "$UPDATE_MODE" == 1 ]]; then
    local i var state
    for ((i = 0; i < ${#items[@]}; i += 3)); do
      var="$(checklist_var "${items[i]}")" || continue
      state=OFF
      if [[ "${!var:-0}" == 1 ]]; then
        state=ON
        if [[ -n "$TUI_BIN" ]] && feature_changed "${items[i]}"; then
          state=LOCKED
          items[i + 1]="${items[i + 1]} — UPDATE"
        fi
      fi
      items[i + 2]="$state"
    done
  fi
  if [[ -n "$TUI_BIN" ]]; then
    local rc=0
    choices="$("$TUI_BIN" checklist "AI CLI Ultimate" "${items[@]}" </dev/tty)" || rc=$?
    if [[ "$rc" == 2 ]]; then
      # Older TUI binary without LOCKED support: degrade to plain ON.
      local i
      for ((i = 2; i < ${#items[@]}; i += 3)); do
        [[ "${items[i]}" == LOCKED ]] && items[i]=ON
      done
      rc=0
      choices="$("$TUI_BIN" checklist "AI CLI Ultimate" "${items[@]}" </dev/tty)" || rc=$?
    fi
    [[ "$rc" == 0 ]] || return 1
  else
    choices="$(whiptail --title "AI CLI Ultimate" --separate-output --checklist \
      "Space toggles, arrows move, Enter confirms." 30 74 20 \
      "${items[@]}" \
      </dev/tty 3>&1 1>&2 2>&3)" || return 1
  fi
  TARGET_CODEX=0 TARGET_CLAUDE=0 TARGET_OPENCODE=0 TARGET_OMP=0 TARGET_ANTIGRAVITY=0
  STATUSLINE=0 LSP=0 CAVEMAN=0 CAVEMAN_ALWAYS=0 PONYTAIL=0 PONYTAIL_ALWAYS=0
  ORQUESTRATOR=0 SUPERPOWERS=0 CENTAURY=0 COMPLETIONS=0 SECURITY=0
  FRONTEND=0 PLAYWRIGHT=0 REACT=0 WEBAPP=0 MCPBUILDER=0 GRILLDOCS=0 SECBP=0
  DIFFREVIEW=0 GHFIXCI=0
  local tag var
  while IFS= read -r tag; do
    var="$(checklist_var "$tag")" || continue
    eval "$var=1"
  done <<<"$choices"
  [[ "$CAVEMAN" == 1 ]] || CAVEMAN_ALWAYS=0
  [[ "$PONYTAIL" == 1 ]] || PONYTAIL_ALWAYS=0
  [[ "$TARGET_CODEX" == 1 ]] || { SUPERPOWERS=0; SECURITY=0; }
  if [[ -n "${AICLI_ULTIMATE_LSP:-}" ]]; then
    [[ "$AICLI_ULTIMATE_LSP" =~ ^[01]$ ]] || die "AICLI_ULTIMATE_LSP must be 0 or 1"
    LSP="$AICLI_ULTIMATE_LSP"
  fi
  if [[ -n "${AICLI_ULTIMATE_EFFORT:-}" ]]; then
    EFFORT="$AICLI_ULTIMATE_EFFORT"
  elif [[ "$UPDATE_MODE" == 1 ]]; then
    : # keep the saved reasoning effort
  elif [[ -n "$TUI_BIN" ]]; then
    EFFORT="$("$TUI_BIN" menu "Reasoning effort" \
      xhigh "Best quality (default)" \
      high "Balanced" \
      medium "Fastest" \
      </dev/tty)" || return 1
  else
    EFFORT="$(whiptail --title "AI CLI Ultimate" --menu "Reasoning effort" 12 50 3 \
      xhigh "Best quality (default)" \
      high "Balanced" \
      medium "Fastest" \
      </dev/tty 3>&1 1>&2 2>&3)" || return 1
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
  # A piped script can be newer or older than the downloaded tree (e.g. raw
  # main install.sh + latest release bundle). Run the tree's own installer so
  # the logic always matches the files it installs.
  # Run in the foreground (not exec) so this parent process survives to fire its
  # own EXIT trap and remove TEMP_DIR, regardless of the child installer's version.
  if [[ -z "${AICLI_ULTIMATE_BOOTSTRAPPED:-}" && -f "$TEMP_DIR/install.sh" ]]; then
    export AICLI_ULTIMATE_BOOTSTRAPPED=1
    bash "$TEMP_DIR/install.sh"
    exit $?
  fi
  ROOT="$TEMP_DIR"
}

install_codex_if_missing() {
  command -v codex >/dev/null 2>&1 && return
  ask "Codex CLI is missing. Install @openai/codex with npm?" y || die "Codex CLI is required"
  command -v npm >/dev/null || die "npm is required to install Codex automatically"
  [[ "$OFFLINE" == 1 ]] || npm install -g @openai/codex
}

run_as_root() {
  if [[ "$EUID" == 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    warn "Cannot install tmux automatically without root access or sudo."
    return 1
  fi
}

install_tmux_if_missing() {
  local manager=""
  command -v tmux >/dev/null 2>&1 && return 0
  [[ "$OFFLINE" != 1 ]] || return 1

  if [[ "$(uname -s)" == Darwin ]] && command -v brew >/dev/null 2>&1; then
    manager=brew
  else
    for manager in apt-get dnf yum pacman zypper apk brew; do
      command -v "$manager" >/dev/null 2>&1 && break
      manager=""
    done
  fi
  if [[ -z "$manager" ]]; then
    warn "Cannot install tmux automatically: no supported package manager found."
    return 1
  fi

  info "Installing tmux for the Codex Powerline"
  case "$manager" in
    apt-get)
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get update \
        && run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y tmux
      ;;
    dnf|yum) run_as_root "$manager" install -y tmux ;;
    pacman) run_as_root pacman -S --needed --noconfirm tmux ;;
    zypper) run_as_root zypper --non-interactive install tmux ;;
    apk) run_as_root apk add tmux ;;
    brew) brew install tmux ;;
  esac || return 1
  command -v tmux >/dev/null 2>&1
}

backup_file() {
  local file="$1" backup="$2"
  [[ -e "$file" ]] || return 0
  mkdir -p "$backup/$(dirname "${file#$HOME/}")"
  cp -a "$file" "$backup/${file#$HOME/}"
}

migrate_legacy_codex_roles() {
  local role file state description tmp
  for role in planner researcher reviewer; do
    file="$CODEX_HOME/agents/$role.toml"
    [[ -f "$file" ]] || continue
    if ! state="$(python3 - "$file" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    role = tomllib.load(handle)
name = role.get("name")
if isinstance(name, str) and name.strip():
    print("valid")
else:
    description = role.get("description")
    print("missing-name" if isinstance(description, str) and description.strip() else "missing-both")
PY
)"; then
      warn "Keeping malformed legacy Codex role unchanged: $file"
      continue
    fi
    [[ "$state" != valid ]] || continue
    case "$role" in
      planner) description="Plans changes before implementation." ;;
      researcher) description="Explores repositories and reports actionable findings." ;;
      reviewer) description="Reviews diffs for concrete defects." ;;
    esac
    tmp="$file.aicli-ultimate.tmp"
    {
      printf 'name = "%s"\n' "$role"
      [[ "$state" == missing-both ]] && printf 'description = "%s"\n' "$description"
      awk -v state="$state" '
        /^[[:space:]]*name[[:space:]]*=/ {next}
        state == "missing-both" && /^[[:space:]]*description[[:space:]]*=/ {next}
        {print}
      ' "$file"
    } >"$tmp"
    mv "$tmp" "$file"
    info "Repaired legacy Codex role: $file"
  done
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

retain_owned_file() {
  local target="$1"
  if [[ -e "$target" && -e "$target.aicli-ultimate-owned" ]]; then
    printf '%s\n' "$target" >>"$NEW_MANIFEST"
  fi
}

install_language_servers() {
  local packages=()
  [[ "$LSP" == 1 ]] || return 0
  retain_owned_file "$GITHUB_LSP_BIN"
  if [[ "$TARGET_CODEX" == 1 || "$TARGET_ANTIGRAVITY" == 1 ]]; then
    retain_owned_file "$MCPLS_BIN"
  fi
  [[ "$OFFLINE" != 1 ]] || return 0

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
  local rc path_value marker_start='# >>> aicli-ultimate >>>' marker_end='# <<< aicli-ultimate <<<'
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
    path_value="$BIN_DIR"
    if [[ "$TARGET_CODEX" == 1 && -f "$CODEX_SHIM.aicli-ultimate-owned" ]]; then
      path_value="$(dirname "$CODEX_SHIM"):$path_value"
    fi
    printf 'export PATH="%s:$PATH"\n' "$path_value"
    printf 'command -v aicli >/dev/null 2>&1 && aicli notify\n'
    [[ "$TARGET_OPENCODE" == 1 && "$LSP" == 1 ]] \
      && printf 'export OPENCODE_EXPERIMENTAL_LSP_TOOL=true\n'
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
    printf '%s\n' "$destination" >>"$NEW_MANIFEST"
  done
}

# Remove owned files/skills recorded by a previous install that this run no
# longer installs (stale after an upgrade or a narrower selection). Everything
# is backed up before removal and only marker-verified paths are touched.
prune_orphans() {
  local path
  if [[ ! -r "$MANIFEST" ]]; then
    sort -u "$NEW_MANIFEST" >"$MANIFEST"
    rm -f "$NEW_MANIFEST"
    return 0
  fi
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    grep -Fxq "$path" "$NEW_MANIFEST" && continue
    if [[ -d "$path" && -e "$path/.aicli-ultimate-owned" ]]; then
      backup_file "$path" "$backup"
      rm -rf "$path"
      info "Removed stale owned skill: $path"
    elif [[ -f "$path" && -e "$path.aicli-ultimate-owned" ]]; then
      backup_file "$path" "$backup"
      rm -f "$path" "$path.aicli-ultimate-owned"
      info "Removed stale owned file: $path"
    fi
  done <"$MANIFEST"
  sort -u "$NEW_MANIFEST" >"$MANIFEST"
  rm -f "$NEW_MANIFEST"
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
  printf '%s\n' "$target" >>"$NEW_MANIFEST"
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

  if [[ "$OFFLINE" != 1 ]] && command -v agy >/dev/null 2>&1; then
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
    if [[ "$OFFLINE" == 1 ]]; then
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
  add_git_include 'hasconfig:remote.*.url:ssh://git@github.com/CentuaryAI/**' "$guard_config"
}

install_plugin() {
  local plugin="$1" required="${2:-1}" ownership_marker="${3:-}" adopt="${4:-0}" plugin_list
  plugin_list="$(codex plugin list 2>/dev/null || true)"
  if grep -Eq "^${plugin//./\.}[[:space:]]+installed" <<<"$plugin_list"; then
    info "Plugin already installed: $plugin"
    if [[ "$adopt" == 1 && -n "$ownership_marker" ]]; then
      mkdir -p "$(dirname "$ownership_marker")"
      touch "$ownership_marker"
    fi
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

remove_owned_codex_plugins_for_shared_skills() {
  local marker_dir="$CONFIG_HOME/native-plugins" marketplace_marker plugin marker plugin_list failed=0
  marketplace_marker="$marker_dir/codex-marketplace-aicli-ultimate"
  plugin_list="$(codex plugin list 2>/dev/null || true)"
  [[ -f "$marketplace_marker" ]] || {
    if grep -Eq '^(caveman|ponytail|centaury-workflow|orquestrator|apollo-rust-best-practices)@aicli-ultimate[[:space:]]+installed' <<<"$plugin_list"; then
      warn "Keeping unowned Codex plugins; duplicate bundled skills may remain until they are removed manually."
    fi
    return 0
  }
  for plugin in caveman ponytail centaury-workflow orquestrator apollo-rust-best-practices; do
    marker="$marker_dir/codex-$plugin"
    [[ "$plugin" == apollo-rust-best-practices ]] \
      && marker="$marker_dir/codex-apollo-rust-best-practices"
    if grep -Eq "^$plugin@aicli-ultimate[[:space:]]+installed" <<<"$plugin_list"; then
      if codex plugin remove "$plugin@aicli-ultimate"; then
        rm -f "$marker"
      else
        warn "Could not remove owned Codex plugin: $plugin@aicli-ultimate"
        failed=1
      fi
    else
      rm -f "$marker"
    fi
  done
  if [[ "$failed" == 0 ]]; then
    codex plugin marketplace remove aicli-ultimate \
      && rm -f "$marketplace_marker" \
      || warn "Could not remove the owned Codex marketplace."
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
  [[ "$OFFLINE" == 1 ]] && return 0
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

RELEASE_VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || printf dev)"
if [[ -r "$STATE_FILE" ]]; then
  PREVIOUS_RELEASE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("release", "unknown"))' "$STATE_FILE" 2>/dev/null || printf unknown)"
  if [[ "$PREVIOUS_RELEASE" == "$RELEASE_VERSION" ]]; then
    info "Existing installation ($PREVIOUS_RELEASE) detected; reinstalling."
  else
    info "Existing installation ($PREVIOUS_RELEASE) detected; upgrading to $RELEASE_VERSION."
  fi
fi

# Update mode (aicli update): reuse the selections saved by the previous
# install and skip every prompt. Same release = nothing to do.
UPDATE_MODE=0
if [[ "${AICLI_ULTIMATE_UPDATE:-0}" == 1 ]]; then
  saved_selections="$(python3 -c 'import json,sys
for key, value in json.load(open(sys.argv[1]))["selections"].items():
    print(f"{key}={value}")' "$STATE_FILE" 2>/dev/null || true)"
  if [[ -n "$saved_selections" ]]; then
    while IFS= read -r selection; do
      [[ "$selection" =~ ^[A-Z_]+=[A-Za-z0-9]*$ ]] || die "invalid saved selection: $selection"
      eval "$selection"
    done <<<"$saved_selections"
    UPDATE_MODE=1
    PREVIOUS_COMPLETE="$(python3 -c 'import json,sys; print(1 if json.load(open(sys.argv[1])).get("complete", True) else 0)' "$STATE_FILE" 2>/dev/null || printf 1)"
    if [[ "${PREVIOUS_RELEASE:-}" == "$RELEASE_VERSION" && "$PREVIOUS_COMPLETE" == 1 && "$DRY_RUN" != 1 ]]; then
      info "Already up to date ($RELEASE_VERSION); nothing to do."
      exit 0
    fi
  else
    warn "No saved selections in $STATE_FILE; continuing with the normal installer flow."
  fi
fi

TUI_DONE=0
TUI_BIN=""
if [[ "$NONINTERACTIVE" != 1 && -z "${AICLI_ULTIMATE_TARGETS:-}" && -r /dev/tty && -w /dev/tty ]]; then
  resolve_tui_bin
  if [[ -n "$TUI_BIN" ]] || command -v whiptail >/dev/null 2>&1; then
    if run_tui; then
      TUI_DONE=1
    elif [[ "$UPDATE_MODE" == 1 ]]; then
      info "Update cancelled; nothing changed."
      exit 0
    else
      info "Selection cancelled in the checklist; using plain prompts."
    fi
  fi
fi

if [[ "$UPDATE_MODE" == 1 || "$TUI_DONE" == 1 ]]; then
  :
elif [[ -n "${AICLI_ULTIMATE_TARGETS:-}" ]]; then
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
MCPLS_BIN="$BIN_DIR/aicli-mcpls"
GITHUB_LSP_BIN="$BIN_DIR/github-lsp"

if [[ "$TUI_DONE" != 1 && "$UPDATE_MODE" != 1 ]]; then
  EFFORT="${AICLI_ULTIMATE_EFFORT:-xhigh}"
  if [[ "$NONINTERACTIVE" != 1 ]]; then
    read -r -p "Reasoning effort [xhigh/high/medium] (xhigh): " EFFORT </dev/tty || EFFORT=xhigh
    EFFORT="${EFFORT:-xhigh}"
  fi
  ask "Install supported Powerline statuslines?" y && STATUSLINE=1 || STATUSLINE=0
  if [[ -n "${AICLI_ULTIMATE_LSP:-}" ]]; then
    [[ "$AICLI_ULTIMATE_LSP" =~ ^[01]$ ]] || die "AICLI_ULTIMATE_LSP must be 0 or 1"
    LSP="$AICLI_ULTIMATE_LSP"
  else
    ask "Install essential LSP support (Rust, TypeScript/JavaScript, Python, and GitHub Markdown)?" y && LSP=1 || LSP=0
  fi
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
  ask "Install optional web-app testing skill (Anthropic)?" n && WEBAPP=1 || WEBAPP=0
  ask "Install optional MCP builder skill (Anthropic)?" n && MCPBUILDER=1 || MCPBUILDER=0
  ask "Install optional plan-grilling skill with ADR docs (grill-with-docs)?" n && GRILLDOCS=1 || GRILLDOCS=0
  ask "Install optional security best-practices skill (OpenAI)?" n && SECBP=1 || SECBP=0
  ask "Install optional differential security review skill (Trail of Bits)?" n && DIFFREVIEW=1 || DIFFREVIEW=0
  ask "Install optional GitHub Actions fixer skill (OpenAI)?" n && GHFIXCI=1 || GHFIXCI=0
  if [[ "$TARGET_CODEX" == 1 ]]; then
    ask "Install the official Codex Security plugin?" n && SECURITY=1 || SECURITY=0
  else
    SECURITY=0
  fi
fi
[[ "$EFFORT" =~ ^(xhigh|high|medium)$ ]] || die "invalid reasoning effort: $EFFORT"
[[ "$TARGET_CODEX" == 1 && "$DRY_RUN" != 1 ]] && install_codex_if_missing
if [[ "$STATUSLINE" == 1 && "$TARGET_CODEX" == 1 && "$DRY_RUN" != 1 ]]; then
  install_tmux_if_missing || true
fi
CODEX_SHARED_SKILLS=0
if [[ "$TARGET_CODEX" == 1 && ( "$TARGET_OPENCODE" == 1 || "$TARGET_OMP" == 1 ) ]]; then
  CODEX_SHARED_SKILLS=1
fi
CODEX_POWERLINE=0
if [[ "$STATUSLINE" == 1 && "$TARGET_CODEX" == 1 ]] && command -v tmux >/dev/null 2>&1; then
  CODEX_POWERLINE=1
fi

OPTIONAL_SKILLS=$((FRONTEND + PLAYWRIGHT + REACT + WEBAPP + MCPBUILDER + GRILLDOCS + SECBP + DIFFREVIEW + GHFIXCI))
# The "Optional skills" step only runs when selected outside offline mode.
[[ "$OFFLINE" != 1 ]] && (( OPTIONAL_SKILLS > 0 )) || STEP_TOTAL=6

if [[ "$DRY_RUN" == 1 ]]; then
  info "Dry run: no files or configuration will be changed."
  printf 'release: %s\n' "$RELEASE_VERSION"
  printf 'targets: codex=%s claude=%s opencode=%s omp=%s antigravity=%s\n' \
    "$TARGET_CODEX" "$TARGET_CLAUDE" "$TARGET_OPENCODE" "$TARGET_OMP" "$TARGET_ANTIGRAVITY"
  printf 'effort=%s statusline=%s lsp=%s caveman=%s/%s ponytail=%s/%s orquestrator=%s\n' \
    "$EFFORT" "$STATUSLINE" "$LSP" "$CAVEMAN" "$CAVEMAN_ALWAYS" "$PONYTAIL" "$PONYTAIL_ALWAYS" "$ORQUESTRATOR"
  printf 'superpowers=%s centaury=%s completions=%s security=%s optional_skills=%s\n' \
    "$SUPERPOWERS" "$CENTAURY" "$COMPLETIONS" "$SECURITY" "$OPTIONAL_SKILLS"
  exit 0
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
if [[ "$TARGET_CODEX" == 1 ]]; then
  for role in planner researcher reviewer; do
    backup_file "$CODEX_HOME/agents/$role.toml" "$backup"
  done
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
backup_file "$BIN_DIR/aicli" "$backup"
backup_file "$BIN_DIR/aicli-ultimate" "$backup"
backup_file "$BIN_DIR/aicli-ultimate-status" "$backup"
backup_file "$CODEX_SHIM" "$backup"
backup_file "$BIN_DIR/aicli-agent-status" "$backup"
backup_file "$BIN_DIR/aicli-opencode" "$backup"
backup_file "$BIN_DIR/aicli-omp" "$backup"
backup_file "$BIN_DIR/aicli-agy" "$backup"

step "Installing files"
mkdir -p "$INSTALL_DIR" "$CONFIG_HOME" "$BIN_DIR"
MANIFEST="$CONFIG_HOME/manifest.txt"
NEW_MANIFEST="$CONFIG_HOME/manifest.txt.new"
: >"$NEW_MANIFEST"

# Written twice: before the remaining file operations ("complete": false) so
# an interrupted run still leaves a usable aicli/update state, and again at
# finalize ("complete": true). aicli update repairs incomplete installs.
write_state() {
  cat >"$STATE_FILE" <<EOF
{
  "version": 1,
  "release": "$RELEASE_VERSION",
  "installed_at": "$timestamp",
  "backup": "$backup",
  "install_dir": "$INSTALL_DIR",
  "targets": "${AICLI_ULTIMATE_TARGETS:-interactive}",
  "complete": $1,
  "centaury_guard": $([[ "$CENTAURY" == 1 ]] && printf true || printf false),
  "selections": {
    "TARGET_CODEX": $TARGET_CODEX,
    "TARGET_CLAUDE": $TARGET_CLAUDE,
    "TARGET_OPENCODE": $TARGET_OPENCODE,
    "TARGET_OMP": $TARGET_OMP,
    "TARGET_ANTIGRAVITY": $TARGET_ANTIGRAVITY,
    "EFFORT": "$EFFORT",
    "STATUSLINE": $STATUSLINE,
    "LSP": $LSP,
    "CAVEMAN": $CAVEMAN,
    "CAVEMAN_ALWAYS": $CAVEMAN_ALWAYS,
    "PONYTAIL": $PONYTAIL,
    "PONYTAIL_ALWAYS": $PONYTAIL_ALWAYS,
    "ORQUESTRATOR": $ORQUESTRATOR,
    "SUPERPOWERS": $SUPERPOWERS,
    "CENTAURY": $CENTAURY,
    "COMPLETIONS": $COMPLETIONS,
    "SECURITY": $SECURITY,
    "FRONTEND": $FRONTEND,
    "PLAYWRIGHT": $PLAYWRIGHT,
    "REACT": $REACT,
    "WEBAPP": $WEBAPP,
    "MCPBUILDER": $MCPBUILDER,
    "GRILLDOCS": $GRILLDOCS,
    "SECBP": $SECBP,
    "DIFFREVIEW": $DIFFREVIEW,
    "GHFIXCI": $GHFIXCI
  }
}
EOF
}
write_state false

if [[ "$ROOT" != "$INSTALL_DIR" ]]; then
  (cd "$ROOT" && tar --exclude=.git -cf - .) | (cd "$INSTALL_DIR" && tar -xf -)
fi
printf '%s\n' "$RELEASE_VERSION" >"$INSTALL_DIR/VERSION"

install_owned_file "$ROOT/scripts/aicli" "$BIN_DIR/aicli"
[[ -e "$BIN_DIR/aicli.aicli-ultimate-owned" ]] && chmod +x "$BIN_DIR/aicli"

render_agents "$ROOT/config/AGENTS.md" "$CONFIG_HOME/global-instructions.md"

if [[ "$LSP" == 1 && ( "$TARGET_CODEX" == 1 || "$TARGET_ANTIGRAVITY" == 1 ) ]]; then
  install_owned_file "$ROOT/config/mcpls.toml" "$CONFIG_HOME/mcpls.toml"
fi
step "Language servers"
install_language_servers
if [[ "$LSP" == 1 && -x "$MCPLS_BIN" && -f "$MCPLS_BIN.aicli-ultimate-owned" ]] \
  && "$MCPLS_BIN" --version 2>/dev/null | grep -Eq "^mcpls ${MCPLS_VERSION}([[:space:]]|$)"; then
  BRIDGE_READY=1
else
  BRIDGE_READY=0
fi
GITHUB_LSP_READY=0
if [[ "$LSP" == 1 ]]; then
  if [[ -x "$GITHUB_LSP_BIN" && -f "$GITHUB_LSP_BIN.aicli-ultimate-owned" ]]; then
    [[ "$(cat "$GITHUB_LSP_BIN.aicli-ultimate-owned")" == "$GITHUB_LSP_VERSION" ]] \
      && GITHUB_LSP_READY=1
  elif command -v github-lsp >/dev/null 2>&1; then
    GITHUB_LSP_READY=1
  fi
fi
if [[ "$GITHUB_LSP_READY" == 1 && "$OFFLINE" != 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    warn "github-lsp requires the gh CLI; install and authenticate gh before use."
  elif ! gh auth status >/dev/null 2>&1; then
    warn "github-lsp requires an authenticated gh CLI; run: gh auth login"
  fi
fi

step "Configuring agents"
if [[ -f "$CONFIG_HOME/codex-statusline-state.json" ]] \
  && ! python3 "$ROOT/scripts/codex_statusline.py" restore \
    "$CODEX_HOME/config.toml" "$CONFIG_HOME/codex-statusline-state.json"; then
  warn "Keeping legacy Codex status line state; config changed after installation."
fi
if [[ "$TARGET_CODEX" == 1 ]]; then
  mkdir -p "$CODEX_HOME/agents" "$CODEX_HOME/themes"
  migrate_legacy_codex_roles
  status_value='status_line = ["model-with-reasoning", "current-dir", "git-branch", "context-remaining", "five-hour-limit", "weekly-limit"]'
  [[ "$CODEX_POWERLINE" == 1 ]] && status_value='# Native status line disabled; external Powerline wrapper is active.'
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

printf 'statusline=%s\nlsp=%s\ncaveman=%s\nponytail=%s\ncodex_skills=%s\n' \
  "$([[ "$CODEX_POWERLINE" == 1 ]] && printf enabled || printf disabled)" \
  "$([[ "$LSP" == 1 ]] && printf enabled || printf disabled)" \
  "$([[ "$CAVEMAN_ALWAYS" == 1 ]] && printf wenyan-ultra || printf off)" \
  "$([[ "$PONYTAIL_ALWAYS" == 1 ]] && printf full || printf off)" \
  "$([[ "$CODEX_SHARED_SKILLS" == 1 ]] && printf shared || printf native)" >"$CONFIG_HOME/modes"

if [[ "$TARGET_CODEX" == 1 ]]; then
  sed "s|@STATUS_COMMAND@|$BIN_DIR/aicli-ultimate-status|g" \
    "$ROOT/statusline/tmux.conf" >"$CONFIG_HOME/tmux.conf"
  install_owned_file "$ROOT/statusline/codex-powerline" "$BIN_DIR/aicli-ultimate"
  install_owned_file "$ROOT/statusline/codex-powerline" "$CODEX_SHIM"
  install_owned_file "$ROOT/statusline/codex-powerline-status" "$BIN_DIR/aicli-ultimate-status"
fi

step "Shell integration"
configure_shell

if [[ "$STATUSLINE" == 1 && "$TARGET_CODEX" == 1 ]]; then
  if [[ "$CODEX_POWERLINE" != 1 ]]; then
    warn "Codex Powerline needs tmux. Native Codex status line remains enabled; install tmux and rerun for Powerline."
  else
    missing=()
    for command in jq sqlite3 git; do command -v "$command" >/dev/null || missing+=("$command"); done
    if ((${#missing[@]})); then
      warn "Codex Powerline installed with limited metrics; optional tools missing: ${missing[*]}."
    fi
  fi
fi

if [[ "$STATUSLINE" == 1 && "$TARGET_CLAUDE" == 1 ]] && ! command -v jq >/dev/null; then
  warn "Claude statusline requires jq. Claude Code will ignore output until jq is installed."
fi

if [[ "$STATUSLINE" == 1 && "$TARGET_ANTIGRAVITY" == 1 ]] && ! command -v jq >/dev/null; then
  warn "Antigravity statusline requires jq; Antigravity will ignore output until jq is installed."
fi

if [[ "$OFFLINE" != 1 && "$TARGET_CODEX" == 1 ]]; then
  codex_marker_dir="$CONFIG_HOME/native-plugins"
  if [[ "$CODEX_SHARED_SKILLS" == 1 ]]; then
    remove_owned_codex_plugins_for_shared_skills
    info "Codex uses the shared bundled skills in $HOME/.agents/skills (one copy)."
  else
    marketplace_list="$(codex plugin marketplace list 2>/dev/null || true)"
    if ! awk '{print $1}' <<<"$marketplace_list" | grep -qx aicli-ultimate; then
      codex plugin marketplace add "$INSTALL_DIR"
      mkdir -p "$codex_marker_dir"
      touch "$codex_marker_dir/codex-marketplace-aicli-ultimate"
    fi
    [[ -f "$codex_marker_dir/codex-marketplace-aicli-ultimate" ]] \
      && codex_adopt_plugins=1 || codex_adopt_plugins=0
    if [[ "$CAVEMAN" == 1 ]]; then
      install_plugin caveman@aicli-ultimate 1 "$codex_marker_dir/codex-caveman" "$codex_adopt_plugins"
    fi
    if [[ "$PONYTAIL" == 1 ]]; then
      install_plugin ponytail@aicli-ultimate 1 "$codex_marker_dir/codex-ponytail" "$codex_adopt_plugins"
    fi
    if [[ "$CENTAURY" == 1 ]]; then
      install_plugin centaury-workflow@aicli-ultimate 1 "$codex_marker_dir/codex-centaury-workflow" "$codex_adopt_plugins"
    fi
    if [[ "$ORQUESTRATOR" == 1 ]]; then
      install_plugin orquestrator@aicli-ultimate 1 "$codex_marker_dir/codex-orquestrator" "$codex_adopt_plugins"
    fi
    install_plugin apollo-rust-best-practices@aicli-ultimate 1 \
      "$codex_marker_dir/codex-apollo-rust-best-practices" "$codex_adopt_plugins"
  fi
  if [[ "$SUPERPOWERS" == 1 ]]; then install_plugin superpowers@openai-curated 0; fi
  if [[ "$SECURITY" == 1 ]]; then install_plugin codex-security@openai-curated 0; fi
fi

if [[ "$OFFLINE" != 1 ]] && (( OPTIONAL_SKILLS > 0 )); then
  step "Optional skills"
  skills_agent_list="$(skills_agents)"
  install_optional_skill() {
    local ref="$1" name="$2"
    # shellcheck disable=SC2086 -- $skills_agent_list is a controlled space-separated allow-list
    # </dev/null: with -y this runs non-interactive; without it the skills CLI
    # drains and echoes stdin, which under `curl … | bash` is the script pipe
    # (dumps the rest of install.sh to the terminal).
    if npx skills add "$ref" -g -y -a $skills_agent_list </dev/null; then
      info "Installed optional skill: $name"
    else
      warn "Could not install optional skill: $name"
    fi
  }
  [[ "$FRONTEND" == 1 ]] && install_optional_skill anthropics/skills@frontend-design frontend-design
  [[ "$PLAYWRIGHT" == 1 ]] && install_optional_skill microsoft/playwright-cli@playwright-cli playwright-cli
  [[ "$REACT" == 1 ]] && install_optional_skill vercel-labs/agent-skills@vercel-react-best-practices vercel-react-best-practices
  [[ "$WEBAPP" == 1 ]] && install_optional_skill anthropics/skills@webapp-testing webapp-testing
  [[ "$MCPBUILDER" == 1 ]] && install_optional_skill anthropics/skills@mcp-builder mcp-builder
  if [[ "$GRILLDOCS" == 1 ]]; then
    # grill-with-docs delegates to the /grilling and /domain-modeling skills.
    install_optional_skill mattpocock/skills@grill-with-docs grill-with-docs
    install_optional_skill mattpocock/skills@grilling grilling
    install_optional_skill mattpocock/skills@domain-modeling domain-modeling
  fi
  [[ "$SECBP" == 1 ]] && install_optional_skill openai/skills@security-best-practices security-best-practices
  [[ "$DIFFREVIEW" == 1 ]] && install_optional_skill trailofbits/skills@differential-review differential-review
  [[ "$GHFIXCI" == 1 ]] && install_optional_skill openai/skills@gh-fix-ci gh-fix-ci
fi

step "Finalizing"
prune_orphans
write_state true

printf '\n\033[1;32mAI CLI Ultimate installed.\033[0m\n'
printf '\033[1;33mRestart your shell and every configured agent to load this install.\033[0m\n'
printf 'Skills are available through each agent native skill syntax or natural language.\n'
printf 'Update anytime with `aicli update`; browse the docs with `aicli docs`.\n'
if [[ "$TARGET_CODEX" == 1 ]]; then
  printf 'Codex diagnostics: aicli-ultimate --doctor\n'
  [[ "$ORQUESTRATOR" == 1 ]] \
    && printf 'Codex Orquestrator: use `$orquestrator-hcom` or natural language; `/orchestration` is not a Codex command.\n'
fi
[[ "$CENTAURY" == 1 ]] && printf 'CentauryAI repositories now block direct commits and pushes to protected branches.\n'
