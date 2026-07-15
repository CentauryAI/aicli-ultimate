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

Existing files are copied to `~/.config/aicli-ultimate/backups/<timestamp>` before changes. After the first install, update with `aicli update` instead of rerunning this command.

### Non-interactive install

```bash
curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | \
  AICLI_ULTIMATE_NONINTERACTIVE=1 \
  AICLI_ULTIMATE_TARGETS=codex,claude,opencode,omp,antigravity \
  bash
```

`AICLI_ULTIMATE_TARGETS` accepts any comma-separated subset of `codex`, `claude`, `opencode`, `omp`, and `antigravity`. See the complete settings table below. `AICLI_ULTIMATE_DRY_RUN=1` prints the selection plan and exits without installing or changing user configuration; a development checkout may still compile its local setup TUI before the plan is printed.

The installer shows a full-screen checklist TUI (ratatui, keyboard + mouse: click toggles, wheel scrolls) via a prebuilt `aicli-tui` binary from the release, or a local `cargo build` in a dev checkout; without either it falls back to `whiptail`, then to sequential prompts. Re-running the installer upgrades in place: it reports the previous release, overwrites only files it owns, and removes owned files a newer release no longer ships (after backing them up).

### Installer settings

The interactive checklist is the complete feature selector. Core features are on by default; optional specialist/security skills are off by default.

| Setting | Default | What it does |
|---|---:|---|
| Target CLIs | Codex + detected CLIs | Chooses which of Codex, Claude Code, OpenCode, OMP, and Antigravity receive configuration. |
| Powerline statuslines | On | Installs each host's supported status UI; Codex uses an external tmux Powerline. |
| LSP support | On | Installs/configures Rust, TypeScript/JavaScript, Python, and GitHub Markdown language servers. |
| Caveman + always-on | On | Installs terse-output skills/plugins and adds a persistent global rule when always-on is selected. |
| Ponytail + always-on | On | Installs minimal-engineering skills/plugins and adds a persistent global rule when always-on is selected. |
| HCOM Orquestrator | On | Installs the pure-delegation workflow; HCOM itself remains a separate install. |
| Superpowers | On for Codex | Installs the official curated Codex Superpowers plugin. |
| CentauryAI workflow | On | Installs safe branch/PR instructions and conditional Git guards for CentauryAI remotes. |
| Shell completions | On | Adds completion setup for Codex and OMP in the current shell. |
| Codex Security | Off | Installs the official curated Codex Security plugin. |
| Optional skills | Off | Installs only the selected frontend, testing, React, MCP, planning, security-review, or CI workflows. |

Supported environment settings:

| Variable | Default | Effect |
|---|---|---|
| `AICLI_ULTIMATE_TARGETS` | Interactive detection | Comma-separated subset of `codex,claude,opencode,omp,antigravity`. |
| `AICLI_ULTIMATE_NONINTERACTIVE` | `0` | With `1`, accepts default answers; core features stay on and optional skills stay off. |
| `AICLI_ULTIMATE_LSP` | Interactive/default on | Forces LSP setup with `0` or `1`. |
| `AICLI_ULTIMATE_EFFORT` | `xhigh` | Codex reasoning effort: `xhigh`, `high`, or `medium`. |
| `AICLI_ULTIMATE_REF` | `main` | Pins source to a branch or release tag such as `v0.4.1`. |
| `AICLI_ULTIMATE_OFFLINE` | `0` | With `1`, skips post-download dependency fetches, native plugin changes, and optional skills; it does not remove the initial download needed by a piped install. |
| `AICLI_ULTIMATE_DRY_RUN` | `0` | With `1`, prints the resolved plan and makes no changes. |
| `AICLI_ULTIMATE_REPO` | `CentauryAI/aicli-ultimate` | Overrides the source repository for forks/testing. |
| `AICLI_ULTIMATE_INSTALL_DIR` | `~/.local/share/aicli-ultimate` | Overrides managed installation files. |
| `AICLI_ULTIMATE_BIN_DIR` | `~/.local/bin` | Overrides installed wrappers and helper binaries. |
| `CODEX_HOME` | `~/.codex` | Overrides the Codex configuration root. |

There are no hidden non-interactive variables for every checklist toggle. Rerun the interactive installer to change Caveman/Ponytail always-on rules, Orquestrator, Powerlines, CentauryAI guards, completions, Superpowers, Codex Security, or individual optional skills. Use `AICLI_ULTIMATE_DRY_RUN=1` first to inspect a non-interactive plan.

### Releases and versioning

Git semver tags are the release version source. The release workflow writes the tag (for example `v0.4.1`) into the packaged `VERSION` file, builds platform TUI binaries, and publishes the bundle. Pin a deployment with `AICLI_ULTIMATE_REF=v0.4.1`; omit it to install the latest published release with a `main` fallback.

### Updates and docs (`aicli`)

The installer places an `aicli` helper in `~/.local/bin`:

- `aicli update` checks the latest GitHub release and exits immediately when you are already current (it also repairs an installation whose previous run was interrupted). When a newer release exists it reruns the installer in update mode: the checklist opens pre-filled from your saved selections instead of from scratch — features you had installed stay selected (deselect one to uninstall it), features whose bundled files changed in the new release appear highlighted as `— UPDATE` and cannot be deselected, and features new to the release appear unselected for you to opt in. Cancelling the checklist aborts the update without changes. Without a terminal (or with the `whiptail` fallback, which cannot lock items) the saved selections are reused as-is.
- `aicli update --check` only reports whether an update exists.
- `aicli docs [name]` browses the bundled documentation (README and `docs/`) in the terminal; it renders markdown with [glow](https://github.com/charmbracelet/glow) when installed and falls back to your pager. Example: `aicli docs orquestrator`.
- `aicli notify` runs at shell startup (added to the managed shell block): it prints a one-line hint when a newer release exists, using a local cache refreshed in the background at most once per day, so it never slows the prompt.

## Native adapters

| CLI | Global rules | Skills/plugins | Extra configuration |
|---|---|---|---|
| Codex | `~/.codex/AGENTS.md` | bundled Codex marketplace | Rust, TypeScript, Python, and GitHub Markdown through the token-limited `mcpls` bridge; profile, agents, Midnight Blue, Powerline |
| Claude Code | `~/.claude/CLAUDE.md` | deduplicated personal skills + official Caveman/Ponytail/LSP plugins + bundled GitHub LSP plugin | Rust, TypeScript/JavaScript, Python, and GitHub Markdown LSP; lifecycle hooks, subagents, Powerline |
| OpenCode | `~/.config/opencode/AGENTS.md` | shared portable skills | built-in Rust/TypeScript/Python LSP plus GitHub Markdown, subagents, Tokyo Night, native TUI plugin |
| OMP | `~/AGENTS.md` | shared portable skills | lazy Rust/TypeScript/Python auto-detection plus GitHub Markdown, native full Powerline plus footer hook |
| Antigravity CLI | global plugin rule | deduplicated aggregate skills + official Caveman/Ponytail plugins | Rust, TypeScript, Python, and GitHub Markdown through the token-limited `mcpls` bridge; native extensions, command statusline |

Managed instruction blocks and JSON path updates preserve unrelated content. Existing statusline settings are backed up and restored by the uninstaller. Files and skill directories owned by another setup are never replaced.

### Generated files and runtime settings

Rerun the installer to change managed features; direct edits to setup-owned generated files may be overwritten on upgrade.

| Path | Purpose |
|---|---|
| `~/.config/aicli-ultimate/install-state.json` | Installed release, targets, timestamp, backup path, and Centaury guard state. |
| `~/.config/aicli-ultimate/modes` | Runtime statusline, LSP, Caveman, Ponytail, and Codex skill-source state. |
| `~/.config/aicli-ultimate/backups/<timestamp>/` | Pre-change copies used for manual recovery. |
| `~/.codex/aicli-ultimate.config.toml` | Generated Codex profile: reasoning effort, custom agents, LSP bridge, theme, and native status fallback. |
| `~/.codex/AGENTS.md` | Managed global Codex working agreements, including selected always-on modes. |
| `~/.claude/CLAUDE.md` | Managed global Claude Code rules. |
| `~/.config/opencode/AGENTS.md` | Managed global OpenCode rules. |
| `~/AGENTS.md` | Managed OMP rules. |
| `~/.hcom/config.toml` | HCOM launch/routing settings; owned by HCOM, not this installer. |

The installed `codex` shim starts real Codex with `--profile aicli-ultimate`; set `AICLI_ULTIMATE_PROFILE=<profile>` only when you have created another valid Codex profile. User-level Codex settings remain in `~/.codex/config.toml`, while trusted projects may add `.codex/config.toml` overrides. See the official [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference#configtoml). Restart Codex after changing profiles, skills, plugins, or `AGENTS.md`, because instruction discovery occurs at session start.

## Language servers

The default LSP set is deliberately small: `rust-analyzer`, `typescript-language-server` plus `typescript`, `pyright`, and [`github-language-server/github-lsp`](https://github.com/github-language-server/github-lsp). Missing Rust and Node binaries are installed through `rustup` and `npm`; the pinned GitHub LSP release is checksum-verified. Existing installations are reused. GitHub LSP requires an installed and authenticated `gh` CLI and provides GitHub Markdown completions and hover information for issues, pull requests, wikis, owners, repositories, and organization members.

Claude Code receives official Rust, TypeScript, and Python LSP plugins plus the bundled GitHub LSP plugin. OpenCode enables its built-in servers and a custom GitHub Markdown entry. OMP discovers Rust, TypeScript, and Python lazily and loads GitHub LSP from its user LSP config.

Codex and Antigravity CLI do not expose a native LSP client, so AI CLI Ultimate uses the pinned, checksum-verified [`mcpls`](https://github.com/bug-ops/mcpls) bridge for those hosts. Seven focused semantic tools are exposed: hover, definition, references, workspace symbol search, diagnostics, implementations, and completions. Formatting, mutation, logs, and other noisy tools remain excluded. This is an LSP bridge, not GitHub MCP Server; no GitHub API MCP is installed. Uninstall removes the bridge, its config, and the setup-owned GitHub LSP binary. Shared Rust, TypeScript, and Python binaries remain available to other editors and agents.

## Skills and plugins

Skills activate explicitly or when a request matches their description. Codex follows its native skill syntax: run `/skills` or type `$` to choose one, for example `$caveman`, `$ponytail`, `$rust-best-practices`, `$centaury-branch-workflow`, or `$orquestrator-hcom`. `/caveman` and `/orchestration` are not expected Codex commands. See the official [Codex skill activation guide](https://learn.chatgpt.com/docs/build-skills#how-codex-uses-skills).

| Host | Explicit activation | Specialist worker roles |
|---|---|---|
| Codex | `/skills`, `$skill-name`, or natural language | Mention `@ultimate-planner`, `@ultimate-researcher`, or `@ultimate-reviewer`. |
| Claude Code | Installed personal skill slash command or natural language | Ask Claude to use the installed `ultimate-*` subagent. |
| OpenCode | Native skill picker/name or natural language | Mention `@ultimate-planner`, `@ultimate-researcher`, or `@ultimate-reviewer`. |
| OMP | `/skill:<name>` or natural language | No bundled `ultimate-*` roles; use skills or an HCOM worker. |
| Antigravity | Native aggregate-skill discovery or natural language | No bundled `ultimate-*` roles; use skills or an HCOM worker. |

The three `ultimate-*` roles are read-only by default:

- `ultimate-planner`: produces a bounded implementation plan, risks, files, and checks;
- `ultimate-researcher`: explores code and reports concise file/line evidence;
- `ultimate-reviewer`: audits a diff for concrete bugs, regressions, security issues, and unnecessary complexity.

They are local subagents, not Orquestrator mode. Use them for one bounded role inside the current CLI. Use Orquestrator when the current thread must coordinate independent agents across terminals and avoid implementation itself.

Common mode controls:

| Feature | Start in Codex | Stop/change | Effect |
|---|---|---|---|
| Caveman | `$caveman` or “use Caveman” | “stop caveman”; request `lite`, `full`, or `ultra` | Reduces prose/token use while preserving technical content. |
| Ponytail | `$ponytail` or “use Ponytail” | “stop ponytail”; request `lite`, `full`, or `ultra` | Enforces YAGNI, standard library/native features, and smallest correct changes. |
| Rust best practices | `$rust-best-practices` | Ends with the task | Applies Apollo's ownership, error, Clippy, performance, test, and documentation guidance. |
| Centaury workflow | Automatic on matching remotes, or `$centaury-branch-workflow` | Ends with the repository task | Protects default branches and requires duplicate checks, verification, PRs, and guarded cleanup. |
| Orquestrator | `$orquestrator-hcom` or “use Orquestrator mode” | “exit orchestrator”, “stop orquestrator”, or “normal mode” | Makes the current thread a pure HCOM coordinator. |

When Codex and OpenCode/OMP are selected together, Codex reuses their single `~/.agents/skills` copy instead of installing duplicate native plugins. Run `aicli-ultimate --doctor` to check the Codex profile, theme, statusline blockers, optional metrics, and bundled-skill source.

Bundled marketplace plugins:

- `caveman`: concise, technically complete communication and review;
- `ponytail`: YAGNI and smallest-correct-implementation engineering mode;
- `centaury-workflow`: safe company branches, duplicate-work checks, validation, pull requests, and merge decisions;
- `orquestrator`: pure multi-agent delegation through HCOM;
- `apollo-rust-best-practices`: Apollo GraphQL guidance for idiomatic Rust, ownership, errors, Clippy, performance, testing, and documentation.

Apollo Rust Best Practices is the one always-installed bundled skill for selected hosts; it has no checklist toggle. Other bundled entries follow their corresponding checklist setting.

The installer can also add official Superpowers and Codex Security, plus optional skills: frontend, Playwright, React, web-app testing (Anthropic), MCP builder (Anthropic), grill-with-docs plan grilling with ADR docs, security best practices (OpenAI), differential security review (Trail of Bits), and a GitHub Actions fixer (OpenAI). Optional skills install only into the CLIs selected for this setup.

| Optional entry | Installed skill(s) | Use it for |
|---|---|---|
| Frontend | `frontend-design` | UI implementation and visual design decisions. |
| Playwright | `playwright-cli` | Browser automation and end-to-end testing. |
| React | `vercel-react-best-practices` | React/Next.js implementation and review guidance. |
| Web-app testing | `webapp-testing` | Interactive web application verification. |
| MCP builder | `mcp-builder` | Designing and implementing MCP servers. |
| Grill with docs | `grill-with-docs`, `grilling`, `domain-modeling` | Stress-testing plans while maintaining ADRs and domain terminology. |
| Security best practices | `security-best-practices` | Secure-by-default Python, JavaScript/TypeScript, and Go guidance. |
| Differential review | `differential-review` | Security-focused review of commits, branches, and pull requests. |
| GitHub Actions fixer | `gh-fix-ci` | Inspecting GitHub Actions failures and preparing approved fixes. |

Official Superpowers and Codex Security are Codex plugins rather than portable optional skills. Their availability and commands are defined by the installed curated plugin version.

Claude and Antigravity keep their upstream native Caveman/Ponytail hooks and omit matching portable copies. OpenCode and OMP use portable skills only, avoiding a second native copy of Ponytail. Existing unowned plugins are preserved; uninstall removes or disables only integrations enabled by AI CLI Ultimate.

## HCOM Orquestrator

The optional `orquestrator-hcom` skill delegates work through [hcom](https://github.com/aannoo/hcom). It enables pure delegation, threaded worker/reviewer coordination, event-driven monitoring, and CentauryAI-safe branch/PR rules. AI CLI Ultimate installs the portable skill only; install HCOM separately from its upstream repository, and let HCOM manage its own hooks.

See the [Orquestrator agent setup and operating guide](docs/orquestrator-agent-setup.md) for recommended pool sizes, tool routing, coordinator visibility, and ready-to-use delegation and review templates.

### Activate Orquestrator mode

1. Select **HCOM Orquestrator mode** in the AI CLI Ultimate installer.
2. Install HCOM separately and add its hooks for the tools you use:

   ```bash
   hcom --help
   hcom hooks add codex       # repeat with claude/opencode/omp/etc. as selected
   hcom hooks status
   ```

3. Restart every configured CLI so both the skill and HCOM hooks load, then verify connectivity:

   ```bash
   hcom status
   hcom list --json
   ```

4. Activate the skill in the coordinator:

   ```text
   Codex:       $orquestrator-hcom Coordinate this task through HCOM.
   Claude Code: /orquestrator-hcom Coordinate this task through HCOM.
   OpenCode:    Use the orquestrator-hcom skill for this task.
   OMP:         /skill:orquestrator-hcom Coordinate this task through HCOM.
   Antigravity: Use the orquestrator-hcom skill for this task.
   ```

Once active, the coordinator does not implement code. It reads `hcom list --json`, selects compatible live workers, delegates bounded ownership, monitors `hcom events`, assigns a different reviewer, verifies the result, and coordinates PR integration. It asks before spawning new external agents and cleans up only agents it created.

The coordinator uses a two-axis mode gate (workflow depth: Direct or SDD; decision gate: none, Deliberation, or Consult) and performs a capacity scan on every user request to match idle agents to useful roles. Idle agents are not a reason to invent work; coordination cost may justify leaving them idle.

### Worker mode and worker/reviewer pipelines

There is no global **worker mode** toggle. A worker is an agent given a bounded task. Choose the path that matches the role:

- local read-only worker: invoke `@ultimate-planner`, `@ultimate-researcher`, or `@ultimate-reviewer` in Codex/OpenCode, or the equivalent Claude subagent, for planning, investigation, or review;
- implementation worker: use a compatible native general-purpose subagent supplied by the host, or launch/connect a cross-terminal agent with HCOM and send it a bounded task using the exact name HCOM returns.

Manual HCOM example:

```bash
hcom --help
hcom codex
hcom list --json
hcom send @exact-returned-name --intent request --thread feature-x -- \
  "Implement the bounded task on a task branch; run repository checks and report the commit."
hcom events --thread feature-x --wait 60
```

Never copy placeholder names from this README. Read the launch output or `hcom list --json`, then use that exact agent name. Before using an unfamiliar HCOM command/flag, run `hcom <command> --help`; installed help is authoritative.

For a worker/reviewer pipeline, give implementation to one agent, wait for its result through the same thread, then send the resulting branch/commit to a different compatible agent for read-only review:

```bash
hcom send @worker-name --intent request --thread feature-x -- \
  "Implement <scope>; own <files>; verify with <commands>; report branch and commit."
hcom events --thread feature-x --wait 60
hcom send @reviewer-name --intent request --thread feature-x -- \
  "Review <branch-or-commit> read-only; report actionable file:line findings or No issues."
```

### HCOM settings used by Orquestrator

Use the CLI instead of editing HCOM configuration blindly:

```bash
hcom config
hcom config terminal --info
hcom config codex_args --info
hcom config auto_approve --info
hcom config -i <exact-agent-name>
```

| HCOM key | What it controls |
|---|---|
| `terminal` | Where visible worker windows/panes open. |
| `tag` | Group label; tagged agents can be addressed as a group. |
| `*_args` | Default native CLI arguments, such as `codex_args` or `claude_args`. |
| `auto_approve` | Auto-approval for HCOM's documented safe command set. |
| `auto_trust_workspace` | Skips supported CLI folder-trust prompts for the launch directory. |
| `hints` | Text appended to messages an agent receives. |
| `notes` | Text appended once to an agent bootstrap. |
| `subagent_timeout` | Keep-alive window for delegated subagents. |
| `name_export` | Optional environment variable that receives the HCOM agent name. |

HCOM precedence is defaults, then `~/.hcom/config.toml`, then environment settings. Use `HCOM_DIR` to isolate a project/workflow. `hcom config -i <name>` manages supported per-agent values. HCOM hooks transport messages; Orquestrator prompt rules define worker behavior, ownership, review separation, and communication style.

### Troubleshooting activation

- Skill missing: rerun the installer with Orquestrator selected, restart the CLI, then use the host syntax above.
- Codex command missing: use `$orquestrator-hcom` or `/skills`; `/orchestration` is not installed.
- No workers: run `hcom list --json`; launch a compatible tool only after checking `hcom <tool> --help`.
- Messages not arriving: verify `hcom status`, hooks, exact agent name, intent, and thread.
- Stale Codex instructions or settings: restart Codex; it reads `AGENTS.md`, skills, and profile configuration when a new session starts. See [Codex AGENTS.md loading](https://learn.chatgpt.com/docs/agent-configuration/agents-md) and the [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference#configtoml).

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

Codex Powerline requires `tmux` and Bash 3.2 or later. When Codex Powerline is selected, the installer installs missing `tmux` through Homebrew or the detected Linux package manager; if automatic installation is unavailable or fails, Codex's native status line remains enabled. AI CLI Ultimate places an owned `codex` shim first on the managed shell `PATH`, so direct and `hcom codex` launches use the same external three-row tmux Powerline. The shim also propagates that path to nested launchers such as HCOM before executing real Codex, without replacing the Codex binary. `jq`, `sqlite3`, and `git` add usage, session, and repository metrics but no longer disable Powerline when missing. Mouse-wheel scrolling enters tmux copy mode instead of changing Codex prompt history; scroll back to the bottom or press `q` to return. Claude and Antigravity require `jq`; all decorated statuslines benefit from a Nerd Font. The installer adds OpenCode's `@opentui/core` peer dependency without replacing other packages. Existing OpenCode plugins, OMP status settings, and unrelated Antigravity settings are preserved; overridden Claude/Antigravity statuslines are restored by uninstall when they remain installer-owned.

## Uninstall

```bash
~/.local/share/aicli-ultimate/uninstall.sh
```

The uninstaller removes setup-owned plugins, GitHub LSP, wrappers, LSP bridge, shell block, OpenCode/OMP LSP settings, and conditional Git guard. Backups remain available and restoration is optional.
HCOM owns its hooks. If a hook was added only for this setup and no other HCOM workflow needs it, remove that specific host with `hcom hooks remove <tool>`; otherwise keep it. Follow HCOM's upstream uninstall instructions if desired. Failed native-plugin removals keep their ownership markers so rerunning the uninstaller can retry safely.

## Development

```bash
./tests/test.sh
```

Tests cover syntax, JSON, isolated multi-CLI installation, conditional Git hooks, and protected-branch behavior. Codex also loads and installs each bundled plugin in an isolated home during release verification.

## License

MIT
