#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/statusline/codex-powerline" "$ROOT/statusline/codex-powerline-status" "$ROOT/statusline/claude-powerline-status" "$ROOT/git-hooks/pre-commit" "$ROOT/git-hooks/pre-push"; do
  bash -n "$script"
done

python3 -m py_compile "$ROOT/scripts/"*.py

python3 -m json.tool "$ROOT/.agents/plugins/marketplace.json" >/dev/null
for manifest in "$ROOT"/plugins/*/.codex-plugin/plugin.json; do
  python3 -m json.tool "$manifest" >/dev/null
done

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
grep -q -- '--profile' "$TMP/home/.local/bin/aicli-ultimate"
grep -q 'model_reasoning_effort = "xhigh"' "$TMP/home/.codex/aicli-ultimate.config.toml"
python3 - "$TMP/home/.codex/aicli-ultimate.config.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tomllib.load(handle)
PY
grep -q 'Respond in English' "$TMP/home/.codex/AGENTS.md"
grep -q 'CentauryAI repositories' "$TMP/home/.codex/AGENTS.md"
grep -q 'hooksPath' "$TMP/home/.config/aicli-ultimate/centaury.gitconfig"
grep -q 'Respond in English' "$TMP/home/.claude/CLAUDE.md"
grep -q 'Respond in English' "$TMP/home/.config/opencode/AGENTS.md"
grep -q 'Respond in English' "$TMP/home/AGENTS.md"
grep -q '"theme": "tokyonight"' "$TMP/home/.config/opencode/tui.json"
grep -q '"name": "aicli-ultimate"' "$TMP/home/.gemini/config/plugins/aicli-ultimate/plugin.json"
test -f "$TMP/home/.claude/skills/caveman/SKILL.md"
test -f "$TMP/home/.agents/skills/ponytail/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/centaury-branch-workflow/SKILL.md"
test -f "$TMP/home/.claude/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/agents/ultimate-reviewer.md"
grep -q '^set -g status-interval 10$' "$TMP/home/.config/aicli-ultimate/tmux.conf"

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

printf 'All tests passed.\n'
