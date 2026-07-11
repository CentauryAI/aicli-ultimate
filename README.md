# AI CLI Ultimate

Portable, interactive setup for Codex, Claude Code, OpenCode, OMP (Oh My Pi), and Antigravity CLI on Linux, macOS, or WSL. It installs shared English rules, specialist agents, portable skills, compatible themes/statuslines, backups, and the CentauryAI protected-branch workflow.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | bash
```

The installer pulls the latest published [release](https://github.com/CentauryAI/aicli-ultimate/releases) bundle when one exists and falls back to the `main` branch otherwise. Set `AICLI_ULTIMATE_REF=vX.Y.Z` to pin a specific release tag.

The installer detects installed CLIs and asks which ones to configure. Safe defaults enable:

- high-effort Codex configuration, memories, multi-agent support, goals, and plugins when Codex is selected;
- native global English instructions for every selected CLI;
- essential Rust, TypeScript/JavaScript, Python, and GitHub Markdown language servers with native LSP integration where supported;
- Caveman and Ponytail modes;
- native Caveman/Ponytail lifecycle plugins where each host supports them;
- optional HCOM Orquestrator mode and a portable pure-delegation skill;
- Apollo GraphQL's Rust best-practices skill across every selected CLI;
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

`AICLI_ULTIMATE_TARGETS` accepts any comma-separated subset of `codex`, `claude`, `opencode`, `omp`, and `antigravity`. Other optional variables include `AICLI_ULTIMATE_LSP=0|1`, `AICLI_ULTIMATE_EFFORT`, `CODEX_HOME`, `AICLI_ULTIMATE_REF`, `AICLI_ULTIMATE_INSTALL_DIR`, and `AICLI_ULTIMATE_BIN_DIR`. `AICLI_ULTIMATE_DRY_RUN=1` prints the selection plan and exits without changing anything.

The installer shows a full-screen checklist TUI (ratatui, keyboard + mouse: click toggles, wheel scrolls) via a prebuilt `aicli-tui` binary from the release, or a local `cargo build` in a dev checkout; without either it falls back to `whiptail`, then to sequential prompts. Re-running the installer upgrades in place: it reports the previous release, overwrites only files it owns, and removes owned files a newer release no longer ships (after backing them up).

## Native adapters

| CLI | Global rules | Skills/plugins | Extra configuration |
|---|---|---|---|
| Codex | `~/.codex/AGENTS.md` | bundled Codex marketplace | Rust, TypeScript, Python, and GitHub Markdown through the token-limited `mcpls` bridge; profile, agents, Midnight Blue, Powerline |
| Claude Code | `~/.claude/CLAUDE.md` | personal skills + official Caveman/Ponytail/LSP plugins + bundled GitHub LSP plugin | Rust, TypeScript/JavaScript, Python, and GitHub Markdown LSP; lifecycle hooks, subagents, Powerline |
| OpenCode | `~/.config/opencode/AGENTS.md` | shared skills + Ponytail server plugin | built-in Rust/TypeScript/Python LSP plus GitHub Markdown, subagents, Tokyo Night, native TUI plugin |
| OMP | `~/AGENTS.md` | shared skills + Ponytail Pi plugin | lazy Rust/TypeScript/Python auto-detection plus GitHub Markdown, native full Powerline plus footer hook |
| Antigravity CLI | global plugin rule | aggregate skills + official Caveman/Ponytail plugins | Rust, TypeScript, Python, and GitHub Markdown through the token-limited `mcpls` bridge; native extensions, command statusline |

Managed instruction blocks and JSON path updates preserve unrelated content. Existing statusline settings are backed up and restored by the uninstaller. Files and skill directories owned by another setup are never replaced.

## Language servers

The default LSP set is deliberately small: `rust-analyzer`, `typescript-language-server` plus `typescript`, `pyright`, and [`github-language-server/github-lsp`](https://github.com/github-language-server/github-lsp). Missing Rust and Node binaries are installed through `rustup` and `npm`; the pinned GitHub LSP release is checksum-verified. Existing installations are reused. GitHub LSP requires an installed and authenticated `gh` CLI and provides GitHub Markdown completions and hover information for issues, pull requests, wikis, owners, repositories, and organization members.

Claude Code receives official Rust, TypeScript, and Python LSP plugins plus the bundled GitHub LSP plugin. OpenCode enables its built-in servers and a custom GitHub Markdown entry. OMP discovers Rust, TypeScript, and Python lazily and loads GitHub LSP from its user LSP config.

Codex and Antigravity CLI do not expose a native LSP client, so AI CLI Ultimate uses the pinned, checksum-verified [`mcpls`](https://github.com/bug-ops/mcpls) bridge for those hosts. Seven focused semantic tools are exposed: hover, definition, references, workspace symbol search, diagnostics, implementations, and completions. Formatting, mutation, logs, and other noisy tools remain excluded. This is an LSP bridge, not GitHub MCP Server; no GitHub API MCP is installed. Uninstall removes the bridge, its config, and the setup-owned GitHub LSP binary. Shared Rust, TypeScript, and Python binaries remain available to other editors and agents.

## Skills and plugins

Codex skills are not custom slash commands. Invoke them as `$caveman`, `$ponytail`, `$rust-best-practices`, `$orquestrator-hcom`, with `@name`, or naturally; `/caveman` and `/orchestration` are not expected in Codex's slash menu. When Codex and OpenCode/OMP are selected together, Codex reuses their single `~/.agents/skills` copy instead of installing duplicate native plugins. Run `aicli-ultimate --doctor` to check the Codex profile, theme, statusline blockers, optional metrics, and bundled-skill source. Claude Code exposes personal skills as slash commands. OMP exposes `/skill:<name>`. OpenCode and Antigravity discover and invoke skills through their native skill systems.

Bundled marketplace plugins:

- `caveman`: concise, technically complete communication and review;
- `ponytail`: YAGNI and smallest-correct-implementation engineering mode;
- `centaury-workflow`: safe company branches, duplicate-work checks, validation, pull requests, and merge decisions;
- `orquestrator`: pure multi-agent delegation through HCOM;
- `apollo-rust-best-practices`: Apollo GraphQL guidance for idiomatic Rust, ownership, errors, Clippy, performance, testing, and documentation.

The installer can also add official Superpowers and Codex Security, plus optional skills: frontend, Playwright, React, web-app testing (Anthropic), MCP builder (Anthropic), grill-with-docs plan grilling with ADR docs, security best practices (OpenAI), differential security review (Trail of Bits), and a GitHub Actions fixer (OpenAI). Optional skills install only into the CLIs selected for this setup.

Claude plugins include their upstream `SessionStart`, `UserPromptSubmit`, and subagent hooks. OpenCode and OMP use Ponytail's official host adapters. Caveman has no upstream OpenCode or OMP lifecycle plugin, so those hosts use the same global always-on rule and portable skills instead of a fake compatibility layer. Existing native plugins are detected and preserved; uninstall removes or disables only integrations enabled by AI CLI Ultimate.

## HCOM Orquestrator

The optional `orquestrator-hcom` skill delegates work through [hcom](https://github.com/aannoo/hcom), a multi-agent orchestration runtime. It enables pure delegation, threaded worker/reviewer coordination, event-driven monitoring, and CentauryAI-safe branch/PR rules. When selected, AI CLI Ultimate installs a pinned, checksum-verified hcom release if missing and enables its hooks only for selected CLIs. Existing hooks are preserved; uninstall removes only hooks it added and leaves the shared hcom binary available for other tools.

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

Codex Powerline requires `tmux` and Bash 3.2 or later; without tmux, the installer keeps Codex's native status line enabled. `jq`, `sqlite3`, and `git` add usage, session, and repository metrics but no longer disable Powerline when missing. Mouse-wheel scrolling enters tmux copy mode instead of changing Codex prompt history; scroll back to the bottom or press `q` to return. Claude and Antigravity require `jq`; all decorated statuslines benefit from a Nerd Font. The installer adds OpenCode's `@opentui/core` peer dependency without replacing other packages. Existing OpenCode plugins, OMP status settings, and unrelated Antigravity settings are preserved; overridden Claude/Antigravity statuslines are restored by uninstall when they remain installer-owned.

## Uninstall

```bash
~/.local/share/aicli-ultimate/uninstall.sh
```

The uninstaller removes setup-owned plugins, GitHub LSP, wrappers, LSP bridge, shell block, OpenCode/OMP LSP settings, and conditional Git guard. Backups remain available and restoration is optional.
Failed HCOM-hook or native-plugin removals keep their ownership markers so rerunning the uninstaller can retry safely.

## Development

```bash
./tests/test.sh
```

Tests cover syntax, JSON, isolated multi-CLI installation, conditional Git hooks, and protected-branch behavior. Codex also loads and installs each bundled plugin in an isolated home during release verification.

## License

MIT
