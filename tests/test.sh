#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/statusline/codex-powerline" "$ROOT/statusline/codex-powerline-status" "$ROOT/statusline/claude-powerline-status" "$ROOT/statusline/antigravity-powerline" "$ROOT/git-hooks/pre-commit" "$ROOT/git-hooks/pre-push"; do
  bash -n "$script"
done

python3 -m py_compile "$ROOT/scripts/"*.py

printf '{"statusLine":{"type":"","command":"status","enabled":true}}\n' >"$TMP/normalized.json"
printf '{"existed":false,"value":null,"installed_value":{"command":"status","enabled":true,"stack_with_default":false}}\n' >"$TMP/normalized-state.json"
python3 "$ROOT/scripts/json_override.py" migrate "$TMP/normalized.json" statusLine \
  '{"command":"status","enabled":true,"stack_with_default":false}' \
  '{"type":"","command":"status","enabled":true}' "$TMP/normalized-state.json"
jq -e '.installed_value.type == "" and (.installed_value | has("stack_with_default") | not)' \
  "$TMP/normalized-state.json" >/dev/null

python3 -m json.tool "$ROOT/.agents/plugins/marketplace.json" >/dev/null
for manifest in "$ROOT"/plugins/*/.codex-plugin/plugin.json; do
  python3 -m json.tool "$manifest" >/dev/null
done

mkdir -p "$TMP/home/.claude" "$TMP/home/.config/opencode" "$TMP/home/.gemini/antigravity-cli"
printf '{"custom":"preserved","statusLine":{"type":"command","command":"legacy-status"}}\n' \
  >"$TMP/home/.claude/settings.json"
printf '{"plugin":["existing-plugin"]}\n' >"$TMP/home/.config/opencode/tui.json"
printf '{"plugin":["existing-server-plugin"]}\n' >"$TMP/home/.config/opencode/opencode.json"
printf '{"custom":"preserved","statusLine":{"command":"legacy-agy","enabled":true}}\n' \
  >"$TMP/home/.gemini/antigravity-cli/settings.json"

HOME="$TMP/home" \
XDG_CONFIG_HOME="$TMP/home/.config" \
CODEX_HOME="$TMP/home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_DRY_RUN=1 \
AICLI_ULTIMATE_TARGETS=codex,claude,opencode,omp,antigravity \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null

test -x "$TMP/home/.local/bin/aicli-ultimate"
test -x "$TMP/home/.local/bin/aicli-ultimate-status"
test -x "$TMP/home/.local/bin/claude-ultimate-status"
test -x "$TMP/home/.local/bin/antigravity-ultimate-status"
grep -q -- '--profile' "$TMP/home/.local/bin/aicli-ultimate"
grep -q 'model_reasoning_effort = "xhigh"' "$TMP/home/.codex/aicli-ultimate.config.toml"
grep -q '^\[mcp_servers.aicli_lsp\]$' "$TMP/home/.codex/aicli-ultimate.config.toml"
grep -q '^enabled = true$' "$TMP/home/.codex/aicli-ultimate.config.toml"
python3 - "$TMP/home/.codex/aicli-ultimate.config.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tomllib.load(handle)
PY
for role in planner researcher reviewer; do
  grep -q "^name = \"ultimate-$role\"$" "$TMP/home/.codex/agents/ultimate-$role.toml"
  grep -q '^description = ' "$TMP/home/.codex/agents/ultimate-$role.toml"
done
grep -q 'Respond in English' "$TMP/home/.codex/AGENTS.md"
grep -q 'CentauryAI repositories' "$TMP/home/.codex/AGENTS.md"
grep -q 'hooksPath' "$TMP/home/.config/aicli-ultimate/centaury.gitconfig"
grep -q 'Respond in English' "$TMP/home/.claude/CLAUDE.md"
grep -q 'Respond in English' "$TMP/home/.config/opencode/AGENTS.md"
grep -q 'Respond in English' "$TMP/home/AGENTS.md"
grep -q '"theme": "tokyonight"' "$TMP/home/.config/opencode/tui.json"
grep -q '"existing-plugin"' "$TMP/home/.config/opencode/tui.json"
jq -e '(.plugin | length) == 2 and (.plugin[1] | endswith("/aicli-ultimate/statusline.js"))' \
  "$TMP/home/.config/opencode/tui.json" >/dev/null
jq -e '.plugin == ["existing-server-plugin", "@dietrichgebert/ponytail"]' \
  "$TMP/home/.config/opencode/opencode.json" >/dev/null
jq -e '.lsp == true and .permission.lsp == "allow"' \
  "$TMP/home/.config/opencode/opencode.json" >/dev/null
jq -e '.dependencies["@opentui/core"] == "*"' "$TMP/home/.config/opencode/package.json" >/dev/null
jq -e '.custom == "preserved" and (.statusLine.command | endswith("/claude-ultimate-status"))' \
  "$TMP/home/.claude/settings.json" >/dev/null
jq -e '.custom == "preserved" and .statusLine.type == "" and .statusLine.enabled == true and (.statusLine.command | endswith("/antigravity-ultimate-status"))' \
  "$TMP/home/.gemini/antigravity-cli/settings.json" >/dev/null
grep -q '"name": "aicli-ultimate"' "$TMP/home/.gemini/config/plugins/aicli-ultimate/plugin.json"
jq -e '.mcpServers["aicli-lsp"].command | endswith("/.local/bin/aicli-mcpls")' \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/mcp_config.json" >/dev/null
jq -e '.mcpServers["aicli-lsp"].disabledTools | length == 14' \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/mcp_config.json" >/dev/null
test -f "$TMP/home/.config/aicli-ultimate/mcpls.toml"
python3 - "$TMP/home/.config/aicli-ultimate/mcpls.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
assert [server["language_id"] for server in config["lsp_servers"]] == ["rust", "typescript", "python"]
PY
test -f "$TMP/home/.claude/skills/caveman/SKILL.md"
test -f "$TMP/home/.agents/skills/ponytail/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/centaury-branch-workflow/SKILL.md"
test -f "$TMP/home/.claude/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.agents/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.claude/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/aicli-ultimate/statusline.js"
grep -q 'app_bottom:' "$TMP/home/.config/opencode/aicli-ultimate/statusline.js"
test -f "$TMP/home/.omp/agent/extensions/aicli-ultimate-statusline.ts"
grep -q '^set -g status-interval 10$' "$TMP/home/.config/aicli-ultimate/tmux.conf"
! grep -q "alias opencode=" "$TMP/home/.bashrc"
! grep -q "alias omp=" "$TMP/home/.bashrc"
! grep -q "alias agy=" "$TMP/home/.bashrc"
grep -q '^export OPENCODE_EXPERIMENTAL_LSP_TOOL=true$' "$TMP/home/.bashrc"
grep -q '^lsp=enabled$' "$TMP/home/.config/aicli-ultimate/modes"
grep -q 'Prefer native LSP tools' "$TMP/home/.codex/AGENTS.md"

claude_payload='{"model":{"display_name":"Claude Test"},"workspace":{"current_dir":"'"$ROOT"'"},"context_window":{"used_percentage":42,"total_input_tokens":12000,"total_output_tokens":3456},"rate_limits":{"five_hour":{"used_percentage":25},"seven_day":{"used_percentage":50}}}'
claude_status="$(printf '%s' "$claude_payload" | HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" "$TMP/home/.local/bin/claude-ultimate-status")"
test "$(printf '%s\n' "$claude_status" | wc -l | tr -d ' ')" = 3
printf '%s' "$claude_status" | grep -q 'Claude Test'

agy_payload='{"agent_state":"working","model":{"display_name":"Gemini Test"},"cwd":"/tmp/project","vcs":{"branch":"ai/test","dirty":true},"context_window":{"used_percentage":42},"task_count":2,"artifact_count":3}'
agy_status="$(printf '%s' "$agy_payload" | HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" "$TMP/home/.local/bin/antigravity-ultimate-status")"
test "$(printf '%s\n' "$agy_status" | wc -l | tr -d ' ')" = 2
printf '%s' "$agy_status" | grep -q 'Gemini Test'

if command -v codex >/dev/null 2>&1; then
  HOME="$TMP/home" CODEX_HOME="$TMP/home/.codex" \
    codex -p aicli-ultimate debug prompt-input smoke >/dev/null 2>"$TMP/codex.err"
  ! grep -q 'malformed agent role definition' "$TMP/codex.err"
fi

mkdir -p "$TMP/company" "$TMP/personal"
git -C "$TMP/company" init -q -b main
git -C "$TMP/company" remote add origin https://github.com/CentauryAI/example.git
git -C "$TMP/personal" init -q -b main
git -C "$TMP/personal" remote add origin https://github.com/example/example.git

company_hooks="$(HOME="$TMP/home" git -C "$TMP/company" config --get core.hooksPath)"
personal_hooks="$(HOME="$TMP/home" git -C "$TMP/personal" config --get core.hooksPath || true)"
test "$company_hooks" = "$TMP/home/.config/aicli-ultimate/git-hooks"
test -z "$personal_hooks"

touch "$TMP/company/tracked"
git -C "$TMP/company" add tracked
if HOME="$TMP/home" git -C "$TMP/company" -c user.name=Test -c user.email=test@example.com commit -m blocked >/dev/null 2>&1; then
  echo "expected protected-branch commit to fail" >&2
  exit 1
fi

git -C "$TMP/company" switch -q -c ai/test-1
HOME="$TMP/home" git -C "$TMP/company" -c user.name=Test -c user.email=test@example.com commit -m allowed >/dev/null

zero=0000000000000000000000000000000000000000
one=1111111111111111111111111111111111111111
if printf 'refs/heads/ai/test-1 %s refs/heads/main %s\n' "$one" "$zero" \
  | "$TMP/home/.config/aicli-ultimate/git-hooks/pre-push" origin https://github.com/CentauryAI/example.git >/dev/null 2>&1; then
  echo "expected protected-branch push to fail" >&2
  exit 1
fi
printf 'refs/heads/ai/test-1 %s refs/heads/ai/test-1 %s\n' "$one" "$zero" \
  | "$TMP/home/.config/aicli-ultimate/git-hooks/pre-push" origin https://github.com/CentauryAI/example.git >/dev/null

HOME="$TMP/home" \
XDG_CONFIG_HOME="$TMP/home/.config" \
CODEX_HOME="$TMP/home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
  "$TMP/home/.local/share/aicli-ultimate/uninstall.sh" >/dev/null
jq -e '.custom == "preserved" and .statusLine.command == "legacy-status"' \
  "$TMP/home/.claude/settings.json" >/dev/null
jq -e '.custom == "preserved" and .statusLine.command == "legacy-agy"' \
  "$TMP/home/.gemini/antigravity-cli/settings.json" >/dev/null
jq -e '.plugin == ["existing-plugin"]' "$TMP/home/.config/opencode/tui.json" >/dev/null
jq -e '.plugin == ["existing-server-plugin"]' "$TMP/home/.config/opencode/opencode.json" >/dev/null
jq -e 'has("lsp") | not' "$TMP/home/.config/opencode/opencode.json" >/dev/null
jq -e 'has("permission") | not' "$TMP/home/.config/opencode/opencode.json" >/dev/null
test ! -e "$TMP/home/.config/opencode/aicli-ultimate/statusline.js"
test ! -e "$TMP/home/.omp/agent/extensions/aicli-ultimate-statusline.ts"
test ! -e "$TMP/home/.config/aicli-ultimate/mcpls.toml"

mkdir -p "$TMP/no-lsp-home"
HOME="$TMP/no-lsp-home" \
XDG_CONFIG_HOME="$TMP/no-lsp-home/.config" \
CODEX_HOME="$TMP/no-lsp-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/no-lsp-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/no-lsp-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_DRY_RUN=1 \
AICLI_ULTIMATE_LSP=0 \
AICLI_ULTIMATE_TARGETS=codex \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null
grep -q '^enabled = false$' "$TMP/no-lsp-home/.codex/aicli-ultimate.config.toml"
test ! -e "$TMP/no-lsp-home/.config/aicli-ultimate/mcpls.toml"

mkdir -p "$TMP/preserved-home/.config/opencode"
printf '{"plugin":["@dietrichgebert/ponytail"]}\n' \
  >"$TMP/preserved-home/.config/opencode/opencode.json"
python3 "$ROOT/scripts/json_add.py" "$TMP/preserved-home/.config/opencode/opencode.json" lsp true
python3 "$ROOT/scripts/json_add.py" "$TMP/preserved-home/.config/opencode/opencode.json" permission.lsp '"allow"'
HOME="$TMP/preserved-home" \
XDG_CONFIG_HOME="$TMP/preserved-home/.config" \
CODEX_HOME="$TMP/preserved-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/preserved-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/preserved-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_DRY_RUN=1 \
AICLI_ULTIMATE_TARGETS=opencode \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null
HOME="$TMP/preserved-home" \
XDG_CONFIG_HOME="$TMP/preserved-home/.config" \
CODEX_HOME="$TMP/preserved-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/preserved-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/preserved-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
  "$TMP/preserved-home/.local/share/aicli-ultimate/uninstall.sh" >/dev/null
jq -e '.plugin == ["@dietrichgebert/ponytail"] and .lsp == true and .permission.lsp == "allow"' \
  "$TMP/preserved-home/.config/opencode/opencode.json" >/dev/null

mkdir -p "$TMP/failure-bin" "$TMP/failure-home/.config/aicli-ultimate/native-plugins"
printf '#!/bin/sh\nexit 1\n' >"$TMP/failure-bin/claude"
chmod +x "$TMP/failure-bin/claude"
touch "$TMP/failure-home/.config/aicli-ultimate/native-plugins/claude-installed-caveman"
PATH="$TMP/failure-bin:/usr/bin:/bin" \
HOME="$TMP/failure-home" \
XDG_CONFIG_HOME="$TMP/failure-home/.config" \
CODEX_HOME="$TMP/failure-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/failure-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/failure-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
  "$ROOT/uninstall.sh" >/dev/null 2>"$TMP/failure.err"
test -f "$TMP/failure-home/.config/aicli-ultimate/native-plugins/claude-installed-caveman"
grep -q 'ownership marker retained' "$TMP/failure.err"

printf 'All tests passed.\n'
