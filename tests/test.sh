#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aicli-ultimate-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

for script in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/statusline/codex-powerline" "$ROOT/statusline/codex-powerline-status" "$ROOT/statusline/claude-powerline-status" "$ROOT/statusline/antigravity-powerline" "$ROOT/git-hooks/pre-commit" "$ROOT/git-hooks/pre-push"; do
  bash -n "$script"
done

# Optional metric tools must not disable or spam the Codex Powerline.
mkdir -p "$TMP/status-bin" "$TMP/status-home/.config/aicli-ultimate"
for command in awk date head mkdir mv rmdir sed stat tail tr wc; do
  ln -s "$(command -v "$command")" "$TMP/status-bin/$command"
done
printf 'caveman=off\nponytail=off\n' >"$TMP/status-home/.config/aicli-ultimate/modes"
PATH="$TMP/status-bin" \
HOME="$TMP/status-home" \
XDG_CONFIG_HOME="$TMP/status-home/.config" \
XDG_CACHE_HOME="$TMP/status-home/.cache" \
  /bin/bash "$ROOT/statusline/codex-powerline-status" 1 \
  >"$TMP/status.out" 2>"$TMP/status.err"
grep -q 'Codex' "$TMP/status.out"
test ! -s "$TMP/status.err"

python3 -m py_compile "$ROOT/scripts/"*.py
python3 -m json.tool "$ROOT/.claude-plugin/marketplace.json" >/dev/null
python3 -m json.tool "$ROOT/plugins/github-lsp/.claude-plugin/plugin.json" >/dev/null
python3 -m json.tool "$ROOT/plugins/github-lsp/.lsp.json" >/dev/null
if command -v claude >/dev/null 2>&1; then
  claude plugin validate --strict "$ROOT" >/dev/null
  claude plugin validate --strict "$ROOT/plugins/github-lsp" >/dev/null
fi

printf '{"custom":"kept","lsp":true}\n' >"$TMP/opencode-lsp.json"
github_lsp_json='{"command":["github-lsp"],"extensions":[".md",".markdown"]}'
python3 "$ROOT/scripts/json_lsp.py" add "$TMP/opencode-lsp.json" github-lsp \
  "$github_lsp_json" "$TMP/opencode-lsp-state.json"
jq -e '.custom == "kept" and .lsp["github-lsp"].command == ["github-lsp"]' \
  "$TMP/opencode-lsp.json" >/dev/null
python3 "$ROOT/scripts/json_lsp.py" remove "$TMP/opencode-lsp.json" github-lsp \
  "$TMP/opencode-lsp-state.json"
jq -e '.custom == "kept" and .lsp == true' "$TMP/opencode-lsp.json" >/dev/null

printf '{"lsp":{"rust":{"disabled":true}}}\n' >"$TMP/opencode-lsp-object.json"
python3 "$ROOT/scripts/json_lsp.py" add "$TMP/opencode-lsp-object.json" github-lsp \
  "$github_lsp_json" "$TMP/opencode-lsp-object-state.json"
python3 "$ROOT/scripts/json_lsp.py" remove "$TMP/opencode-lsp-object.json" github-lsp \
  "$TMP/opencode-lsp-object-state.json"
jq -e '.lsp == {"rust":{"disabled":true}}' "$TMP/opencode-lsp-object.json" >/dev/null

printf '{"statusLine":{"type":"","command":"status","enabled":true}}\n' >"$TMP/normalized.json"
printf '{"existed":false,"value":null,"installed_value":{"command":"status","enabled":true,"stack_with_default":false}}\n' >"$TMP/normalized-state.json"
python3 "$ROOT/scripts/json_override.py" migrate "$TMP/normalized.json" statusLine \
  '{"command":"status","enabled":true,"stack_with_default":false}' \
  '{"type":"","command":"status","enabled":true}' "$TMP/normalized-state.json"
jq -e '.installed_value.type == "" and (.installed_value | has("stack_with_default") | not)' \
  "$TMP/normalized-state.json" >/dev/null

python3 -m json.tool "$ROOT/.agents/plugins/marketplace.json" >/dev/null
jq -e '.plugins | any(.name == "apollo-rust-best-practices" and .source.path == "./plugins/apollo-rust-best-practices")' \
  "$ROOT/.agents/plugins/marketplace.json" >/dev/null
for manifest in "$ROOT"/plugins/*/.codex-plugin/plugin.json; do
  python3 -m json.tool "$manifest" >/dev/null
done

mkdir -p "$TMP/home/.claude" "$TMP/home/.codex/agents" "$TMP/home/.config/opencode" "$TMP/home/.gemini/antigravity-cli"
printf 'description = ""\nmodel = "test"\n' >"$TMP/home/.codex/agents/planner.toml"
printf 'name = ""\ndescription = "Keep custom description."\n' \
  >"$TMP/home/.codex/agents/researcher.toml"
printf 'name = "custom-reviewer"\ndescription = "Keep valid role."\n' \
  >"$TMP/home/.codex/agents/reviewer.toml"
cp "$TMP/home/.codex/agents/reviewer.toml" "$TMP/reviewer-valid.toml"
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
AICLI_ULTIMATE_OFFLINE=1 \
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
grep -q '"get_completions"' "$TMP/home/.codex/aicli-ultimate.config.toml"
python3 - "$TMP/home/.codex/aicli-ultimate.config.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    tomllib.load(handle)
PY
for role in planner researcher reviewer; do
  grep -q "^name = \"ultimate-$role\"$" "$TMP/home/.codex/agents/ultimate-$role.toml"
  grep -q '^description = ' "$TMP/home/.codex/agents/ultimate-$role.toml"
done
grep -q '^name = "planner"$' "$TMP/home/.codex/agents/planner.toml"
grep -q '^description = "Plans changes before implementation."$' \
  "$TMP/home/.codex/agents/planner.toml"
grep -q '^name = "researcher"$' "$TMP/home/.codex/agents/researcher.toml"
grep -q '^description = "Keep custom description."$' \
  "$TMP/home/.codex/agents/researcher.toml"
cmp "$TMP/reviewer-valid.toml" "$TMP/home/.codex/agents/reviewer.toml"
backup_dir="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["backup"])' \
  "$TMP/home/.config/aicli-ultimate/install-state.json")"
grep -q '^model = "test"$' "$backup_dir/.codex/agents/planner.toml"
grep -q '^description = ""$' "$backup_dir/.codex/agents/planner.toml"
grep -q '^name = ""$' "$backup_dir/.codex/agents/researcher.toml"
cmp "$TMP/reviewer-valid.toml" "$backup_dir/.codex/agents/reviewer.toml"
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
jq -e '.lsp["github-lsp"].command == ["github-lsp"] and .permission.lsp == "allow"' \
  "$TMP/home/.config/opencode/opencode.json" >/dev/null
jq -e '.dependencies["@opentui/core"] == "*"' "$TMP/home/.config/opencode/package.json" >/dev/null
jq -e '.custom == "preserved" and (.statusLine.command | endswith("/claude-ultimate-status"))' \
  "$TMP/home/.claude/settings.json" >/dev/null
jq -e '.custom == "preserved" and .statusLine.type == "" and .statusLine.enabled == true and (.statusLine.command | endswith("/antigravity-ultimate-status"))' \
  "$TMP/home/.gemini/antigravity-cli/settings.json" >/dev/null
grep -q '"name": "aicli-ultimate"' "$TMP/home/.gemini/config/plugins/aicli-ultimate/plugin.json"
jq -e '.mcpServers["aicli-lsp"].command | endswith("/.local/bin/aicli-mcpls")' \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/mcp_config.json" >/dev/null
jq -e '(.mcpServers["aicli-lsp"].disabledTools | length) == 13 and (.mcpServers["aicli-lsp"].disabledTools | index("get_completions") | not)' \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/mcp_config.json" >/dev/null
test -f "$TMP/home/.omp/agent/lsp.json"
jq -e '.servers["github-lsp"].command == "github-lsp"' \
  "$TMP/home/.omp/agent/lsp.json" >/dev/null
test -f "$TMP/home/.config/aicli-ultimate/mcpls.toml"
python3 - "$TMP/home/.config/aicli-ultimate/mcpls.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as handle:
    config = tomllib.load(handle)
assert [item["language_id"] for item in config["workspace"]["language_extensions"]] == ["rust", "typescript", "python", "markdown"]
assert [server["language_id"] for server in config["lsp_servers"]] == ["rust", "typescript", "python", "markdown"]
PY
test -f "$TMP/home/.claude/skills/caveman/SKILL.md"
test -f "$TMP/home/.agents/skills/ponytail/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/centaury-branch-workflow/SKILL.md"
test -f "$TMP/home/.claude/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.agents/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/orquestrator-hcom/SKILL.md"
test -f "$TMP/home/.claude/skills/rust-best-practices/SKILL.md"
test -f "$TMP/home/.claude/skills/rust-best-practices/references/chapter_09.md"
test -f "$TMP/home/.agents/skills/rust-best-practices/SKILL.md"
test -f "$TMP/home/.agents/skills/rust-best-practices/references/chapter_09.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/rust-best-practices/SKILL.md"
test -f "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/rust-best-practices/references/chapter_09.md"
force_delete_re='(^|[-*#]+[[:space:]]+|[.;:][[:space:]]+)(Run|Use|Prefer)[[:space:]].*git branch -D'
printf '%s\n' '- Run `git branch -D topic`.' >"$TMP/force-delete-recommendation.md"
printf '%s\n' '- Never use `git branch -D`.' >"$TMP/force-delete-prohibition.md"
grep -Eq "$force_delete_re" "$TMP/force-delete-recommendation.md"
! grep -Eq "$force_delete_re" "$TMP/force-delete-prohibition.md"
for instructions in \
  "$TMP/home/.codex/AGENTS.md" \
  "$TMP/home/.claude/CLAUDE.md" \
  "$TMP/home/.config/opencode/AGENTS.md" \
  "$TMP/home/AGENTS.md"; do
  grep -q 'pull request state as `MERGED`' "$instructions"
  grep -q 'git push --force-with-lease=refs/heads/<branch>:<headRefOid> <remote> --delete <branch>' "$instructions"
  grep -q 'narrow lease authorizes only the guarded deletion' "$instructions"
  grep -q 'git branch -d <branch>' "$instructions"
  ! grep -Eq 'gh pr merge[^`]*--delete-branch' "$instructions"
  ! grep -Eq "$force_delete_re" "$instructions"
done
for skill in \
  "$TMP/home/.claude/skills/centaury-branch-workflow/SKILL.md" \
  "$TMP/home/.agents/skills/centaury-branch-workflow/SKILL.md" \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/centaury-branch-workflow/SKILL.md"; do
  grep -q 'Confirm GitHub reports the pull request state as `MERGED`' "$skill"
  grep -q 'git push --force-with-lease=refs/heads/<branch>:<headRefOid> <remote> --delete <branch>' "$skill"
  grep -q 'narrow lease authorizes deletion only while the remote ref still equals' "$skill"
  grep -q 'Never use `git branch -D`' "$skill"
  ! grep -Eq 'gh pr merge[^`]*--delete-branch' "$skill"
  ! grep -Eq "$force_delete_re" "$skill"
done
for skill in \
  "$TMP/home/.claude/skills/orquestrator-hcom/SKILL.md" \
  "$TMP/home/.agents/skills/orquestrator-hcom/SKILL.md" \
  "$TMP/home/.gemini/config/plugins/aicli-ultimate/skills/orquestrator-hcom/SKILL.md"; do
  grep -q 'Delegate only task-branch-correctable sync or integration failures' "$skill"
  grep -q 'reviewer who is different from the implementer/resolver' "$skill"
  grep -q 'Do not delegate permission failures, missing approvals, required-check failures, ruleset blocks' "$skill"
  grep -q 'HCOM hooks transport and inject messages; they do not rewrite prose' "$skill"
  grep -q 'Orchestrator messages to the human/bigboss use normal concise English' "$skill"
  grep -q 'Every task, review, follow-up, and nested delegation must include' "$skill"
  grep -q '通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。' "$skill"
  ! grep -q 'communication: use Caveman wenyan-ultra' "$skill"
  grep -q 'request one reformatted reply with the contract repeated' "$skill"
done
test -f "$TMP/home/.claude/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/agents/ultimate-reviewer.md"
test -f "$TMP/home/.config/opencode/aicli-ultimate/statusline.js"
grep -q 'app_bottom:' "$TMP/home/.config/opencode/aicli-ultimate/statusline.js"
test -f "$TMP/home/.omp/agent/extensions/aicli-ultimate-statusline.ts"
grep -q '^set -g status-interval 10$' "$TMP/home/.config/aicli-ultimate/tmux.conf"
grep -q '^set -g mouse on$' "$TMP/home/.config/aicli-ultimate/tmux.conf"
grep -q '^bind-key -T root WheelUpPane copy-mode -e$' "$TMP/home/.config/aicli-ultimate/tmux.conf"
! grep -q "alias opencode=" "$TMP/home/.bashrc"
! grep -q "alias omp=" "$TMP/home/.bashrc"
! grep -q "alias agy=" "$TMP/home/.bashrc"
grep -q '^export OPENCODE_EXPERIMENTAL_LSP_TOOL=true$' "$TMP/home/.bashrc"
grep -Fq "export PATH=\"$TMP/home/.local/bin:\$PATH\"" "$TMP/home/.bashrc"
grep -q '^lsp=enabled$' "$TMP/home/.config/aicli-ultimate/modes"
grep -q '^codex_skills=shared$' "$TMP/home/.config/aicli-ultimate/modes"
grep -q 'Prefer native LSP tools' "$TMP/home/.codex/AGENTS.md"

doctor_output="$(HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" CODEX_HOME="$TMP/home/.codex" \
  "$TMP/home/.local/bin/aicli-ultimate" --doctor)"
grep -q 'profile: installed' <<<"$doctor_output"
grep -q 'theme: installed' <<<"$doctor_output"
grep -q 'statusline: Powerline enabled' <<<"$doctor_output"
grep -q 'bundled skills: shared' <<<"$doctor_output"

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
! jq -e '.servers["github-lsp"]' "$TMP/home/.omp/agent/lsp.json" >/dev/null
test ! -e "$TMP/home/.config/aicli-ultimate/mcpls.toml"
test ! -e "$TMP/home/.claude/skills/rust-best-practices"
test ! -e "$TMP/home/.agents/skills/rust-best-practices"

mkdir -p "$TMP/no-lsp-home"
HOME="$TMP/no-lsp-home" \
XDG_CONFIG_HOME="$TMP/no-lsp-home/.config" \
CODEX_HOME="$TMP/no-lsp-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/no-lsp-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/no-lsp-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_OFFLINE=1 \
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
AICLI_ULTIMATE_OFFLINE=1 \
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

mkdir -p "$TMP/hcom-bin" "$TMP/hcom-home"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'if [[ "${CODEX_LEGACY:-0}" == 1 && "$*" == "plugin list" ]]; then' \
  '  printf "caveman@aicli-ultimate  installed\\nponytail@aicli-ultimate  installed\\ncentaury-workflow@aicli-ultimate  installed\\norquestrator@aicli-ultimate  installed\\napollo-rust-best-practices@aicli-ultimate  installed\\n"' \
  'elif [[ "${CODEX_LEGACY:-0}" == 1 && "$*" == "plugin marketplace list" ]]; then' \
  '  printf "aicli-ultimate  installed\\n"' \
  'elif [[ "${CODEX_PREINSTALLED:-0}" == 1 && "$*" == "plugin list" ]]; then' \
  '  printf "apollo-rust-best-practices@aicli-ultimate  installed\\n"' \
  'elif [[ "${CODEX_PREINSTALLED:-0}" == 1 && "$*" == "plugin marketplace list" ]]; then' \
  '  printf "aicli-ultimate  installed\\n"' \
  'fi' \
  'printf "%s\\n" "$*" >>"$HCOM_TEST_LOG"' >"$TMP/hcom-bin/codex"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'touch "$HOME/.hcom-called"' \
  'exit 1' >"$TMP/hcom-bin/hcom"
chmod +x "$TMP/hcom-bin/codex" "$TMP/hcom-bin/hcom"
HCOM_TEST_LOG="$TMP/hcom.log" \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/hcom-home" \
XDG_CONFIG_HOME="$TMP/hcom-home/.config" \
CODEX_HOME="$TMP/hcom-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/hcom-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/hcom-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_LSP=0 \
AICLI_ULTIMATE_TARGETS=codex \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null
test ! -e "$TMP/hcom-home/.hcom-called"
test -f "$TMP/hcom-home/.config/aicli-ultimate/native-plugins/codex-apollo-rust-best-practices"
test -f "$TMP/hcom-home/.config/aicli-ultimate/native-plugins/codex-marketplace-aicli-ultimate"
for plugin in caveman ponytail centaury-workflow orquestrator; do
  test -f "$TMP/hcom-home/.config/aicli-ultimate/native-plugins/codex-$plugin"
done
HCOM_TEST_LOG="$TMP/hcom.log" \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/hcom-home" \
XDG_CONFIG_HOME="$TMP/hcom-home/.config" \
CODEX_HOME="$TMP/hcom-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/hcom-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/hcom-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
  "$TMP/hcom-home/.local/share/aicli-ultimate/uninstall.sh" >/dev/null
test ! -e "$TMP/hcom-home/.hcom-called"
test ! -e "$TMP/hcom-home/.config/aicli-ultimate/native-plugins/codex-apollo-rust-best-practices"
test ! -e "$TMP/hcom-home/.config/aicli-ultimate/native-plugins/codex-marketplace-aicli-ultimate"

mkdir -p "$TMP/shared-home"
HCOM_TEST_LOG="$TMP/shared.log" \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/shared-home" \
XDG_CONFIG_HOME="$TMP/shared-home/.config" \
CODEX_HOME="$TMP/shared-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/shared-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/shared-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_LSP=0 \
AICLI_ULTIMATE_TARGETS=codex,opencode \
SHELL=/bin/bash \
  "$ROOT/install.sh" >"$TMP/shared.out"
test -f "$TMP/shared-home/.agents/skills/orquestrator-hcom/SKILL.md"
grep -q '^codex_skills=shared$' "$TMP/shared-home/.config/aicli-ultimate/modes"
! grep -Eq '^plugin add (caveman|ponytail|centaury-workflow|orquestrator|apollo-rust-best-practices)@aicli-ultimate$' "$TMP/shared.log"
! grep -q '^plugin marketplace add ' "$TMP/shared.log"
grep -Fq 'Codex diagnostics: aicli-ultimate --doctor' "$TMP/shared.out"
grep -Fq 'use `$orquestrator-hcom`' "$TMP/shared.out"
grep -Fq '`/orchestration` is not a Codex command' "$TMP/shared.out"
test ! -e "$TMP/shared-home/.hcom-called"

mkdir -p "$TMP/legacy-home/.config/aicli-ultimate/native-plugins"
touch "$TMP/legacy-home/.config/aicli-ultimate/native-plugins/codex-marketplace-aicli-ultimate"
HCOM_TEST_LOG="$TMP/legacy.log" \
CODEX_LEGACY=1 \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/legacy-home" \
XDG_CONFIG_HOME="$TMP/legacy-home/.config" \
CODEX_HOME="$TMP/legacy-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/legacy-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/legacy-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_LSP=0 \
AICLI_ULTIMATE_TARGETS=codex,opencode \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null
for plugin in caveman ponytail centaury-workflow orquestrator apollo-rust-best-practices; do
  grep -qx "plugin remove $plugin@aicli-ultimate" "$TMP/legacy.log"
done
grep -qx 'plugin marketplace remove aicli-ultimate' "$TMP/legacy.log"
test ! -e "$TMP/legacy-home/.config/aicli-ultimate/native-plugins/codex-marketplace-aicli-ultimate"

mkdir -p "$TMP/preinstalled-home"
HCOM_TEST_LOG="$TMP/preinstalled.log" \
CODEX_PREINSTALLED=1 \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/preinstalled-home" \
XDG_CONFIG_HOME="$TMP/preinstalled-home/.config" \
CODEX_HOME="$TMP/preinstalled-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/preinstalled-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/preinstalled-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_LSP=0 \
AICLI_ULTIMATE_TARGETS=codex \
SHELL=/bin/bash \
  "$ROOT/install.sh" >/dev/null
test ! -e "$TMP/preinstalled-home/.config/aicli-ultimate/native-plugins/codex-apollo-rust-best-practices"
test ! -e "$TMP/preinstalled-home/.config/aicli-ultimate/native-plugins/codex-marketplace-aicli-ultimate"
HCOM_TEST_LOG="$TMP/preinstalled.log" \
CODEX_PREINSTALLED=1 \
PATH="$TMP/hcom-bin:/usr/bin:/bin" \
HOME="$TMP/preinstalled-home" \
XDG_CONFIG_HOME="$TMP/preinstalled-home/.config" \
CODEX_HOME="$TMP/preinstalled-home/.codex" \
AICLI_ULTIMATE_INSTALL_DIR="$TMP/preinstalled-home/.local/share/aicli-ultimate" \
AICLI_ULTIMATE_BIN_DIR="$TMP/preinstalled-home/.local/bin" \
AICLI_ULTIMATE_NONINTERACTIVE=1 \
  "$TMP/preinstalled-home/.local/share/aicli-ultimate/uninstall.sh" >/dev/null
! grep -qx 'plugin remove apollo-rust-best-practices@aicli-ultimate' "$TMP/preinstalled.log"
! grep -qx 'plugin marketplace remove aicli-ultimate' "$TMP/preinstalled.log"

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
