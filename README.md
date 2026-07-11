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
- matching Powerlines through each CLI's native UI/status API where available;
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
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/skills` | subagents, native three-row Powerline |
| OpenCode | `~/.config/opencode/AGENTS.md` | shared `~/.agents/skills` | subagents, Tokyo Night, native TUI plugin |
| OMP | `~/AGENTS.md` | shared `~/.agents/skills` | native full Powerline plus footer hook |
| Antigravity CLI | global plugin rule | global plugin skills | global plugin and native command statusline |

Managed instruction blocks and JSON path updates preserve unrelated content. Existing statusline settings are backed up and restored by the uninstaller. Files and skill directories owned by another setup are never replaced.

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

Codex renders model/reasoning/path/Git/modes, context/tokens/cache, and 5-hour/weekly usage. Claude Code uses its native statusline input with the same palette and three-row geometry. OpenCode uses its TUI slot API for a compact in-app footer that refreshes every 10 seconds. OMP enables its built-in `full` Powerline preset when no user status configuration exists, then adds a native `ctx.ui.setStatus()` footer refreshed every 10 seconds. Antigravity uses its official JSON-input command statusline and updates when the CLI emits state changes. No shell aliases are required.

Codex Powerline dependencies: `tmux`, `jq`, `sqlite3`, `git`, Bash 3.2 or later, and a Nerd Font. Claude and Antigravity require `jq`; all decorated statuslines benefit from a Nerd Font. The installer adds OpenCode's `@opentui/core` peer dependency without replacing other packages. Existing OpenCode plugins, OMP status settings, and unrelated Antigravity settings are preserved; overridden Claude/Antigravity statuslines are restored by uninstall when they remain installer-owned.

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
