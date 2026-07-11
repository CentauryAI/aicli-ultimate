#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/statusline/codex-powerline" "$ROOT/statusline/codex-powerline-status" "$ROOT/statusline/claude-powerline-status" "$ROOT/statusline/aicli-agent-powerline" "$ROOT/statusline/aicli-agent-status" "$ROOT/git-hooks/pre-commit" "$ROOT/git-hooks/pre-push"; do
  bash -n "$script"
done

python3 -m py_compile "$ROOT/scripts/"*.py

python3 -m json.tool "$ROOT/.agents/plugins/marketplace.json" >/dev/null
for manifest in "$ROOT"/plugins/*/.codex-plugin/plugin.json; do
  python3 -m json.tool "$manifest" >/dev/null
done

mkdir -p "$TMP/home/.claude" "$TMP/home/.config/opencode"
printf '{"custom":"preserved","statusLine":{"type":"command","command":"legacy-status"}}\n' \
  >"$TMP/home/.claude/settings.json"
printf '{"plugin":["existing-plugin"]}\n' >"$TMP/home/.config/opencode/tui.json"

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
test -x "$TMP/home/.local/bin/aicli-agent-status"
test -x "$TMP/home/.local/bin/aicli-opencode"
test -x "$TMP/home/.local/bin/aicli-omp"
test -x "$TMP/home/.local/bin/aicli-agy"
grep -q -- '--profile' "$TMP/home/.local/bin/aicli-ultimate"
grep -q 'model_reasoning_effort = "xhigh"' "$TMP/home/.codex/aicli-ultimate.config.toml"
python3 - "$TMP/home/.codex/aicli-ultimate.config.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tomllib.load(handle)
PY
for role in planner researcher reviewer; do
  grep -q "^name = \"ultimate-$role\"$" "$TMP/home/.codex/agents/ultimate-$role.toml"
done
grep -q 'Respond in English' "$TMP/home/.codex/AGENTS.md"
grep -q 'CentauryAI repositories' "$TMP/home/.codex/AGENTS.md"
grep -q 'hooksPath' "$TMP/home/.config/aicli-ultimate/centaury.gitconfig"
grep -q 'Respond in English' "$TMP/home/.claude/CLAUDE.md"
grep -q 'Respond in English' "$TMP/home/.config/opencode/AGENTS.md"
grep -q 'Respond in English' "$TMP/home/AGENTS.md"
grep -q '"theme": "tokyonight"' "$TMP/home/.config/opencode/tui.json"
grep -q '"existing-plugin"' "$TMP/home/.config/opencode/tui.json"
jq -e '.custom == "preserved" and (.statusLine.command | endswith("/claude-ultimate-status"))' \
  "$TMP/home/.claude/settings.json" >/dev/null
grep -q '"name": "aicli-ultimate"' "$TMP/home/.gemini/config/plugins/aicli-ultimate/plugin.json"
test -f "$TMP/home/.claude/skills/caveman/SKILL.md"
test -f "$TMP/home/.agents/skills/ponytail/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/centaury-branch-workflow/SKILL.md"
test -f "$TMP/home/.claude/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/agents/ultimate-reviewer.md"
grep -q '^set -g status-interval 10$' "$TMP/home/.config/aicli-ultimate/tmux.conf"
for agent in opencode omp agy; do
  grep -q '^set -g status-interval 10$' "$TMP/home/.config/aicli-ultimate/tmux-$agent.conf"
done
grep -q "alias opencode='aicli-opencode'" "$TMP/home/.bashrc"
grep -q "alias omp='aicli-omp'" "$TMP/home/.bashrc"
grep -q "alias agy='aicli-agy'" "$TMP/home/.bashrc"

claude_payload='{"model":{"display_name":"Claude Test"},"workspace":{"current_dir":"'"$ROOT"'"},"context_window":{"used_percentage":42,"total_input_tokens":12000,"total_output_tokens":3456},"rate_limits":{"five_hour":{"used_percentage":25},"seven_day":{"used_percentage":50}}}'
claude_status="$(printf '%s' "$claude_payload" | HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" "$TMP/home/.local/bin/claude-ultimate-status")"
test "$(printf '%s\n' "$claude_status" | wc -l | tr -d ' ')" = 3
printf '%s' "$claude_status" | grep -q 'Claude Test'

generic_status="$(HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" XDG_CACHE_HOME="$TMP/cache" "$TMP/home/.local/bin/aicli-agent-status" 1 opencode)"
printf '%s' "$generic_status" | grep -q 'OPENCODE'
AICLI_OPENCODE_REAL_BIN=/bin/echo "$TMP/home/.local/bin/aicli-opencode" run smoke | grep -q 'run smoke'
AICLI_OMP_REAL_BIN=/bin/echo "$TMP/home/.local/bin/aicli-omp" config | grep -q 'config'
AICLI_AGY_REAL_BIN=/bin/echo "$TMP/home/.local/bin/aicli-agy" --print smoke | grep -q -- '--print smoke'

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
test ! -e "$TMP/home/.local/bin/aicli-opencode"

printf 'All tests passed.\n'
