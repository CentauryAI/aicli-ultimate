# AI CLI Ultimate

Portable, interactive setup for Codex, Claude Code, OpenCode, OMP (Oh My Pi), and Antigravity CLI on Linux, macOS, or WSL. It installs shared English rules, specialist agents, portable skills, compatible themes/statuslines, backups, and the CentauryAI protected-branch workflow.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | bash
```

The installer detects installed CLIs and asks which ones to configure. Safe defaults enable:

- high-effort Codex configuration, memories, multi-agent support, goals, and plugins when Codex is selected;
- native global English instructions for every selected CLI;
- Caveman and Ponytail modes;
- native skills and read-only planner, researcher, and reviewer agents where supported;
- official Superpowers for Codex;
- the CentauryAI workflow skill/plugin and conditional protected-branch Git hooks;
- a three-row Codex Powerline and one-row Claude Code Powerline when dependencies exist;
- Midnight Blue for Codex and Tokyo Night for OpenCode.

Existing files are copied to `~/.config/aicli-ultimate/backups/<timestamp>` before changes. Rerun the command to update.

### Non-interactive install

```bash
AICLI_ULTIMATE_NONINTERACTIVE=1 \
AICLI_ULTIMATE_TARGETS=codex,claude,opencode,omp,antigravity \
  curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | bash
```

`AICLI_ULTIMATE_TARGETS` accepts any comma-separated subset of `codex`, `claude`, `opencode`, `omp`, and `antigravity`. Other optional variables include `AICLI_ULTIMATE_EFFORT`, `CODEX_HOME`, `AICLI_ULTIMATE_REF`, `AICLI_ULTIMATE_INSTALL_DIR`, and `AICLI_ULTIMATE_BIN_DIR`.

## Native adapters

| CLI | Global rules | Skills/plugins | Extra configuration |
|---|---|---|---|
| Codex | `~/.codex/AGENTS.md` | bundled Codex marketplace | profile, agents, Midnight Blue, Powerline |
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/skills` | subagents, native Powerline statusline |
| OpenCode | `~/.config/opencode/AGENTS.md` | shared `~/.agents/skills` | subagents, Tokyo Night |
| OMP | `~/AGENTS.md` | shared `~/.agents/skills` | native skill discovery and shell completion |
| Antigravity CLI | global plugin rule | global plugin skills | `~/.gemini/config/plugins/aicli-ultimate` |

Managed instruction blocks preserve unrelated content. Files and skill directories that will be replaced are backed up first.

## Skills and plugins

Codex skills are not custom slash commands. Invoke them as `$caveman`, `$ponytail`, `@caveman`, `@ponytail`, or naturally; `/caveman` is not expected in Codex's slash menu. Claude Code exposes personal skills as slash commands. OMP exposes `/skill:<name>`. OpenCode and Antigravity discover and invoke skills through their native skill systems.

Bundled marketplace plugins:

- `caveman`: concise, technically complete communication and review;
- `ponytail`: YAGNI and smallest-correct-implementation engineering mode;
- `centaury-workflow`: safe company branches, duplicate-work checks, validation, pull requests, and merge decisions.

The installer can also add official Superpowers and Codex Security, plus optional frontend, Playwright, and React skills.

## CentauryAI safety workflow

For GitHub remotes owned by `CentauryAI` (and the legacy `CentuaryAI` spelling), every configured agent is instructed to:

1. check default-branch history, code, branches, and pull requests for completed or overlapping work;
2. create `ai/<task>-<id>` from the current remote default branch before editing;
3. synchronize with the default branch and run repository checks;
4. push only the task branch and integrate through a pull request;
5. merge only after compatibility, required checks, and approvals are established;
6. leave duplicate, conflicting, or failing work unmerged with exact evidence.

Conditional Git hooks block local commits and pushes to `main`, `master`, or the detected default branch. They do not affect unrelated repositories.

Client-side hooks are not security boundaries. Organization administrators should also apply the [recommended GitHub ruleset](docs/github-ruleset.md).

## Powerline statusline

The optional wrapper starts interactive Codex sessions inside an isolated tmux server and renders three decorated rows below Codex: model/reasoning/path/Git/modes, context/tokens/cache, and 5-hour/weekly usage. It refreshes every 10 seconds. Claude Code receives a native event-driven one-row Powerline with model/path/Git/context.

Codex Powerline dependencies: `tmux`, `jq`, `sqlite3`, `git`, Bash 3.2 or later, and a Nerd Font. Claude Powerline requires `jq`, `git`, Bash, and a Nerd Font. Missing Codex dependencies trigger a clean fallback to the normal interface.

## Uninstall

```bash
~/.local/share/aicli-ultimate/uninstall.sh
```

The uninstaller removes setup-owned plugins, wrappers, shell block, and conditional Git guard. Backups remain available and restoration is optional.

## Development

```bash
./tests/test.sh
```

Tests cover syntax, JSON, isolated multi-CLI installation, conditional Git hooks, and protected-branch behavior. Codex also loads and installs each bundled plugin in an isolated home during release verification.

## License

MIT
