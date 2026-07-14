# Orquestrator agent setup and operating guide

This guide explains how to assemble an HCOM worker pool, choose the right agent for each task, and run the `orquestrator-hcom` workflow without unnecessary sessions or overlapping edits.

## How the project fits together

AI CLI Ultimate configures AI coding clients. HCOM connects already-installed clients across terminal sessions. Orquestrator is the prompt-level policy that tells one connected client how to coordinate the others.

| Layer | AI CLI Ultimate responsibility | Owner after installation |
| --- | --- | --- |
| Codex, Claude Code, OpenCode, OMP, and Antigravity adapters | Installs shared rules, skills, supported plugins, LSP integration, and optional statuslines for selected targets | AI CLI Ultimate manages only files and blocks it created |
| `orquestrator-hcom` | Installs the optional pure-delegation skill into selected targets | AI CLI Ultimate |
| HCOM executable, message database, terminal launching, names, and events | Not installed or configured by AI CLI Ultimate | HCOM |
| HCOM message/status hooks | Not added or removed by AI CLI Ultimate | HCOM through `hcom hooks add/remove` |
| Native plugin lifecycle hooks | Installs them when the selected Caveman, Ponytail, LSP, or host plugin provides them | AI CLI Ultimate and the native host plugin manager |
| CentauryAI Git hooks | Installs conditional pre-commit and pre-push guards when selected | AI CLI Ultimate; GitHub rules remain authoritative |
| Models, provider accounts, API keys, and native CLI authentication | Not managed as shared HCOM state | Each native AI client |
| `~/.hcom/config.toml` | Never owned by the AI CLI Ultimate installer | HCOM through `hcom config` |

AI CLI Ultimate deliberately does not run HCOM during install or uninstall. Installing Orquestrator makes the coordination policy available; it does not connect sessions by itself. Add HCOM hooks separately after installing HCOM.

HCOM hooks transport messages and report status. They do not select models, rewrite prompts, enforce Caveman style, assign files, review code, or decide whether a branch can merge. The Orquestrator skill supplies those behavioral rules.

Each selected target receives a native-compatible setup:

| Target | Main installed integration |
| --- | --- |
| Codex | Global `AGENTS.md`, generated profile, bundled marketplace/shared skills, specialist agents, `mcpls` LSP bridge, Midnight Blue, and optional tmux Powerline |
| Claude Code | Global `CLAUDE.md`, personal skills, native plugins and lifecycle hooks, native LSP plugins, specialist subagents, and statusline |
| OpenCode | Global `AGENTS.md`, shared skills, native/built-in LSP configuration, specialist subagents, Tokyo Night, and native TUI integration |
| OMP | Global `AGENTS.md`, shared skills, lazy LSP configuration, Ponytail plugin, and native status UI |
| Antigravity | Global plugin rule, aggregate skills, native plugins, `mcpls` LSP bridge, and command statusline |

Installer target names are `codex`, `claude`, `opencode`, `omp`, and `antigravity`. Antigravity's native executable is `agy`; HCOM still calls its launcher `antigravity`.

The installer invokes supported native plugin managers for selected features, such as Codex marketplace plugins, Claude plugins, OMP plugins, and Antigravity plugins. Rerun AI CLI Ultimate to change installer-owned integrations instead of replaying its internal plugin commands manually.

## Recommended default

Start with three live sessions:

1. one **Codex coordinator** running `orquestrator-hcom`;
2. one **OMP worker** using the expected MiniMax profile;
3. one **OpenCode worker** using the expected Qwen profile.

The coordinator plans, routes, monitors, and verifies. It does not implement. The two workers can implement separate tasks or review each other. This is enough for most repository work.

Add another agent only when its specialty is required:

| Need | Add | Resulting pool |
| --- | --- | ---: |
| Frontend, screenshots, visual work, or image input | 1 Antigravity worker | 4 sessions |
| Mechanical edits, bulk renames, or repetitive work | 1 Claude worker | 4 sessions |
| Security, difficult backend, architecture, or hard final review | 1 additional Codex worker | 4 sessions |
| Two genuinely independent moderate tasks | 1 additional OMP worker | 4 sessions |

Five or six live sessions can help on a large change with separate file ownership. More sessions usually add coordination cost and edit collisions. Scale by independent tasks, not by available model quota.

Practical limits:

- Codex: one coordinator; zero or one additional specialist/reviewer.
- OMP/MiniMax: one by default; two only for independent work.
- OpenCode/Qwen: one by default.
- Claude/DeepSeek: zero by default; add one for cheap mechanical work.
- Antigravity/Gemini: zero by default; add one for frontend or visual work.
- Never let two workers edit the same files at the same time.
- Use a reviewer different from the implementer.

## Tool routing

AI CLI Ultimate's bundled Orquestrator policy expects these profiles:

| HCOM tool | Expected profile | Best use | Avoid |
| --- | --- | --- | --- |
| `claude` | DeepSeek V4 Flash | Cheap, fast, simple, repetitive, or bulk changes | Images, visual work, complex or high-risk reasoning |
| `omp` | MiniMax M3 | Easy-to-moderate agentic work, long context, multimodal input, live internet research (Perplexity web search) | Highest-risk security or architecture decisions |
| `opencode` | Qwen 3.7 Plus | Moderate-to-complex implementation and multimodal input | Maximum-risk security or backend reasoning |
| `antigravity` | Gemini 3.5 Flash | Frontend, visual, multimodal, image input, and image generation | Backend-only work that a cheaper worker can handle |
| `codex` | GPT-5.6 Sol | Research, planning, difficult backend, optimization, security, hard review | Frontend implementation |

These are expected installation profiles, not runtime detection. HCOM reports the worker tool, but not the model configured behind that tool. Confirm native CLI configuration when the exact model matters.

The direct HCOM `gemini` launcher is not assigned a default role by the bundled routing policy. Use it only when its live description explicitly matches the task or after deliberately extending the policy.

Selection order:

1. Exclude incompatible tools.
2. Match domain and required capability.
3. Match complexity.
4. Prefer a `listening` worker over an `active` worker.
5. Never assign a `blocked`, inactive, or stale worker.
6. Among equal candidates, prefer the cheaper profile: Claude, OMP, OpenCode, Antigravity, then Codex.

Examples:

- project-wide rename: Claude;
- ordinary API endpoint: OMP or OpenCode;
- live internet research: OMP (Perplexity web search);
- complex service refactor: OpenCode;
- screenshot-driven UI: Antigravity;
- authentication threat review: Codex;
- mixed frontend and security change: split frontend to Antigravity and security/backend review to Codex.

## What the coordinator can see

Run this before every assignment:

```bash
hcom list --json
```

The result includes each live agent's exact name, tool, status, status age, description, directory, tag, unread count, session metadata, and launch context. Routing should mainly use:

- `name`: exact target for `hcom send`;
- `tool`: CLI type, such as `omp` or `codex`;
- `status`: `listening`, `active`, `blocked`, inactive, or unknown;
- `description`: current live specialization or activity;
- `status_age_seconds`: useful for detecting stale state;
- `directory`: confirms the worker is in the intended workspace.

The coordinator can also inspect:

- messages and state changes with `hcom events`;
- a worker conversation with `hcom transcript <exact-name>` when evidence is needed;
- Git branches, commits, diffs, and repository checks through normal read-only Git commands;
- file collision events with `hcom events --collision`.

The coordinator does **not** automatically know:

- the actual model behind a tool;
- whether a worker's answer is correct;
- what a worker's private subagents did;
- the worker's full conversation unless it queries the transcript;
- whether a branch is safe to merge without inspecting the diff and checks.

Treat worker reports as claims until verified.

## Initial setup

1. Run the interactive AI CLI Ultimate installer:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | bash
   ```

   Select the clients you intend to use plus **HCOM Orquestrator**. The checklist is the complete feature selector.

2. For automation, select targets explicitly. This accepts any subset of `codex`, `claude`, `opencode`, `omp`, and `antigravity`:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/CentauryAI/aicli-ultimate/main/install.sh | \
     AICLI_ULTIMATE_NONINTERACTIVE=1 \
     AICLI_ULTIMATE_TARGETS=codex,opencode,omp \
     bash
   ```

   Non-interactive mode enables core defaults and leaves optional skills off. Use the interactive installer when you need every feature toggle.

3. Restart the shell and every configured AI client. Confirm the Codex-side installation when Codex is selected:

   ```bash
   aicli-ultimate --doctor
   ```

4. Install HCOM separately from its upstream project. AI CLI Ultimate does not install the `hcom` executable.

5. Check installed HCOM syntax before using it:

   ```bash
   hcom --help
   ```

6. Add HCOM delivery/status hooks for each selected host:

   ```bash
   hcom hooks add codex
   hcom hooks add omp
   hcom hooks add opencode
   hcom hooks status
   ```

   Add `claude` or `antigravity` only when you use those workers.

7. Restart each CLI after adding HCOM hooks, then verify connectivity:

   ```bash
   hcom status
   hcom list --json
   ```

8. Inspect settings through the CLI instead of editing HCOM configuration blindly:

   ```bash
   hcom config
   hcom config terminal --info
   hcom config codex_args --info
   hcom config omp_args --info
   hcom config auto_approve --info
   ```

Use `HCOM_DIR` when separate projects need isolated HCOM state. Configuration precedence is built-in defaults, `~/.hcom/config.toml`, then environment settings.

## What users can change

### Installer choices

Rerun the interactive installer to change any checklist option. Reinstallation upgrades in place, backs up affected files, overwrites only installer-owned content, and removes owned files that a newer selection no longer needs.

| Option | What it changes |
| --- | --- |
| Target clients | Configures any selected combination of Codex, Claude Code, OpenCode, OMP, and Antigravity |
| Powerline statuslines | Enables supported host status UI; Codex uses the managed tmux Powerline when available |
| LSP support | Configures Rust, TypeScript/JavaScript, Python, and GitHub Markdown language services |
| Caveman and always-on mode | Installs terse-output support and optionally keeps it active by default |
| Ponytail and always-on mode | Installs minimal-engineering support and optionally keeps it active by default |
| HCOM Orquestrator | Installs the coordination skill; it still does not install HCOM or its hooks |
| Superpowers | Installs the official curated plugin when Codex is selected |
| CentauryAI workflow | Installs global protected-branch instructions and conditional Git guards |
| Shell completions | Adds supported shell completion setup |
| Codex Security | Installs the optional official Codex Security plugin |
| Optional skills | Adds selected frontend, Playwright, React, web-app, MCP, planning, security-review, or CI workflows |
| Codex reasoning effort | Chooses `xhigh`, `high`, or `medium` |

Supported environment controls:

| Variable | Use |
| --- | --- |
| `AICLI_ULTIMATE_TARGETS` | Select a comma-separated client subset |
| `AICLI_ULTIMATE_NONINTERACTIVE=1` | Accept non-interactive defaults |
| `AICLI_ULTIMATE_LSP=0` or `1` | Force LSP off or on |
| `AICLI_ULTIMATE_EFFORT=xhigh\|high\|medium` | Set Codex reasoning effort |
| `AICLI_ULTIMATE_REF=<tag-or-branch>` | Pin the installed release/source ref |
| `AICLI_ULTIMATE_OFFLINE=1` | Skip post-download dependency fetches, native plugin changes, and optional skills |
| `AICLI_ULTIMATE_DRY_RUN=1` | Print the resolved plan without changing user configuration |
| `AICLI_ULTIMATE_REPO=<owner/repo>` | Use a fork or alternate source repository |
| `AICLI_ULTIMATE_INSTALL_DIR=<path>` | Change the managed installation directory |
| `AICLI_ULTIMATE_BIN_DIR=<path>` | Change the managed binary directory |
| `CODEX_HOME=<path>` | Change the Codex configuration root |

There are no hidden environment variables for every checklist item. Use the interactive installer to change statuslines, always-on modes, Orquestrator, Centaury guards, completions, Superpowers, Codex Security, or individual optional skills. Preview automation first with `AICLI_ULTIMATE_DRY_RUN=1`.

### HCOM runtime choices

Use `hcom config <key> --info` before changing a value. Installed CLI help is authoritative.

| Key | What users can tune |
| --- | --- |
| `terminal` | Where new worker windows or panes open |
| `tag` | Group label used to organize or address workers |
| `hints` | Text appended to every message received by an agent |
| `notes` | Bootstrap text appended once when an agent starts |
| `subagent_timeout` | Keep-alive window for delegated subagents |
| `claude_args`, `gemini_args`, `codex_args`, `opencode_args`, `kilo_args`, `pi_args`, `omp_args`, `cursor_args`, `kimi_args`, `copilot_args` | Native launch arguments for each supported tool |
| `auto_approve` | Auto-approval for HCOM's documented safe command set |
| `auto_subscribe` | Event subscription presets |
| `auto_trust_workspace` | Skips supported native folder-trust prompts |
| `name_export` | Optional environment variable receiving the HCOM agent name |

Examples:

```bash
hcom config terminal --info
hcom config omp_args --info
hcom config auto_approve --info
hcom config -i <exact-agent-name>
hcom config -i <exact-agent-name> tag backend
hcom config -i <exact-agent-name> subagent_timeout 900
```

Change the actual model through the native client configuration or its documented launch arguments. Changing an HCOM tag, description, or routing table does not change the model.

### Runtime behavior

These controls do not require reinstalling:

| Behavior | Start or change | Stop |
| --- | --- | --- |
| Caveman | Activate the `caveman` skill; choose `lite`, `full`, `ultra`, `wenyan-lite`, `wenyan-full`, or `wenyan-ultra` | Say `stop caveman` |
| Ponytail | Activate the `ponytail` skill; choose `lite`, `full`, or `ultra` | Say `stop ponytail` |
| Orquestrator | Activate `orquestrator-hcom` or request Orquestrator mode | Say `exit orchestrator`, `stop orquestrator`, or `normal mode` |
| Worker count | Launch another compatible HCOM tool only for an independent task | `hcom kill <owned-worker>` after work is recorded |
| Worker role | Change the bounded task, tag, or task-specific hints | Reassign only while no conflicting task is active |

### Generated and managed files

Prefer installer and CLI controls over direct edits:

| Path | Rule |
| --- | --- |
| `~/.config/aicli-ultimate/install-state.json` | Installer state; do not hand-edit |
| `~/.config/aicli-ultimate/modes` | Generated runtime status; rerun installer or use mode controls |
| `~/.codex/aicli-ultimate.config.toml` | Generated Codex profile; rerun installer for managed values |
| Global `AGENTS.md`/`CLAUDE.md` managed blocks | Unrelated user content is preserved; managed blocks may be replaced on upgrade |
| `~/.agents/skills` and native plugin entries | Installer-owned copies may be updated or removed on rerun |
| `~/.hcom/config.toml` | HCOM-owned; change it through `hcom config` |

User-owned content outside managed blocks remains intact. Existing files are backed up under `~/.config/aicli-ultimate/backups/<timestamp>` before affected changes.

### Diagnostics and removal

```bash
aicli-ultimate --doctor
hcom status
hcom hooks status
hcom list --json
```

Remove AI CLI Ultimate-owned integrations with:

```bash
~/.local/share/aicli-ultimate/uninstall.sh
```

The uninstaller does not uninstall HCOM or remove HCOM hooks. If a hook was added only for this setup and no other HCOM workflow needs it, remove that exact host separately:

```bash
hcom hooks remove <tool>
```

Keep HCOM hooks when another workflow still uses them. HCOM itself follows its own upstream upgrade and uninstall process.

## Start the default pool

The coordinator is the current Codex session. Activate the skill with:

```text
$orquestrator-hcom Coordinate this task through HCOM.
```

Codex is the recommended coordinator for planning and hard verification, but every configured host can activate the portable skill:

| Coordinator host | Activation |
| --- | --- |
| Codex | Select `$orquestrator-hcom` through `/skills` or request it in natural language |
| Claude Code | Run `/orquestrator-hcom` or request it in natural language |
| OpenCode | Select the native skill name or request `orquestrator-hcom` |
| OMP | Run `/skill:orquestrator-hcom` or request it in natural language |
| Antigravity | Use native aggregate-skill discovery or request `orquestrator-hcom` |

There is no global worker-mode switch. A worker is any connected agent receiving a bounded task. The bundled `ultimate-planner`, `ultimate-researcher`, and `ultimate-reviewer` roles are local, read-only specialists inside Codex, Claude Code, or OpenCode; they are useful for one plan, investigation, or review. Use HCOM workers for cross-terminal implementation and independent worker/reviewer pipelines.

Check each launcher's current help, then start only the workers needed now:

```bash
hcom omp --help
hcom omp

hcom opencode --help
hcom opencode
```

Optional specialists:

```bash
hcom claude --help
hcom claude

hcom antigravity --help
hcom antigravity

hcom codex --help
hcom codex
```

Read launch output and `hcom list --json` to obtain exact agent names. Never copy placeholder names from documentation and never guess an agent name.

## Mode lifecycle

Once activated, mode persists for the current conversation until explicit stop. Every user request maintains pure delegation and refreshes live state. A new CLI session requires reactivation. The anti-forget purpose is part of the common contract; host-native hooks are optional.

## CAPS v1

Capability card per worker. Exact format:

```
CAPS v1 | name=<hcom_name> | tool=<tool> | session=<session_id> | skills=<relevant_skills> | commands=<native_commands> | source=<how_known> | limits=<known_limits>
```

Query only the selected worker's relevant capabilities. Cache in coordinator context and the same HCOM thread, keyed by exact name/tool/session_id. Recoverable from thread or events transcript after compaction. No global filesystem cache. session_id empty or changed means refresh or invalidate. Unknown capability means no guess.

## Mode gate

Two independent axes:

**Workflow depth**: Direct (bounded, known cause, low risk, few dependent steps) or SDD (new public behavior, multiple dependent steps or subsystems or implementers, architecture or migration or high risk). Few files can still be SDD if risk or complexity warrants it.

**Decision gate**: none, Deliberation (2+ viable approaches, uncertain tradeoff), or Consult (needs human authority, scope, or product choice). Stackable on either workflow depth.

Risk and ambiguity override file count.

## Worker bootstrap

Pre-existing or bare-launched worker: first task or message must contain full compact protocol. If user authorizes spawn, first disclose tool and count plus compact contract; user authorization suffices, no double approval. Check `hcom <tool> --help`; if `--hcom-system-prompt` is listed, use it; otherwise inject via first task message. Do not guess the flag.

## Peer messaging and progress

Peer messaging only for authorized scope, dependency, or deliberation. Same `--thread`. Target peer plus coordinator. No broad broadcast. No overlapping file ownership.

Progress signals: ack on task receipt, meaningful milestone updates, blocker request with exact error, final evidence with branch/commit/files/checks. No timer spam. Dependency report only on state change or block.

## Independent reviewer

On worker completion signal, assign an independent read-only reviewer who is different from the implementer. Event-driven: no idle between implement and verify. Review provides advisory evidence; coordinator or human retains final authority.

## Operating workflow

### 1. Inspect and split

Understand repository policy and working-tree state first. Split work into bounded tasks with:

- one objective;
- explicit file ownership;
- a task branch;
- acceptance criteria;
- exact checks;
- no overlap with another worker.

Use lightweight specification-driven development when the mode gate selects SDD:

```text
scope -> proposal -> spec -> tasks -> implementation -> independent verification -> PR
```

### 2. Capacity scan

On every user request while mode active:

1. Refresh `hcom list --json` to see current agent state.
2. Derive independent useful roles from the request: investigation, implementation, test analysis, review, or other bounded functions.
3. Match compatible idle agents to those roles using tool-aware routing and CAPS v1 relevant skills/commands. Before assignment, refresh status; if chosen capability is unknown, ask or verify, do not guess.
4. Delegate in parallel only if it materially reduces latency or context usage and file ownership does not overlap.

Idle agents alone are not a reason to invent work. Coordination cost may justify leaving agents idle. Do not spawn or assign agents just because they are available.

**Failure guards**:

1. **Stale state**: Agent idle at scan but busy at dispatch. Guard: re-run `hcom list --json` immediately before each dispatch. Status changed? Skip that agent.
2. **Edit collision**: Two agents write same file. Guard: reserve file scope per agent in task brief. Agent writes nothing outside its list without coordinator approval.
3. **Busywork masked as productivity**: Agent returns nothing usable. Guard: every role must have verifiable deliverable. Generic or unusable output means FAIL; do not re-dispatch.

### 3. Send a bounded implementation task

```bash
hcom send @exact-worker --intent request --thread feature-x -- \
  'Task: implement <bounded behavior>.
Workflow depth: <Direct or SDD>.
Coordinator: <exact hcom name>.
Documentation owner: <exact worker hcom name or none for Direct>.
Branch: <task branch>.
Files owned: <paths>.
Acceptance: <observable result>.
Checks: <exact commands>.
Rules:
- Stay inside assigned files and scope; ask before expanding.
- Report exact failing commands and errors verbatim.
- Follow repository branch and PR policy; never commit to a protected branch.
- Report final branch, commit, changed files, and check results.
通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。'
```

**Artifact rules by workflow depth**:
- **Direct**: No mandatory artifacts. Worker reports via HCOM only.
- **SDD**: Only the designated documentation owner creates task-scoped artifacts (e.g., `docs/tasks/<thread>/WALKTHROUGH.md` and `DECISIONS.md`). All other workers send non-obvious decisions and evidence to coordinator and doc owner via same HCOM thread, never edit shared files.

The final Chinese line is the exact compact worker-communication contract required by the installed skill. Keep code, commands, paths, identifiers, output, and errors verbatim even when prose is compressed.

### 4. Monitor without polling loops

Use HCOM events instead of `sleep`:

```bash
hcom events --thread feature-x --wait 60
```

Useful focused checks:

```bash
hcom events --collision
hcom events --blocked exact-worker
hcom transcript exact-worker --last 10
```

Read a full transcript only when the normal report lacks required evidence.

### 5. Request a correction when needed

Send the exact failing command, error, or review finding back to the original implementer. Keep the same thread and scope. Do not silently repair another worker's branch from the coordinator.

```bash
hcom send @exact-worker --intent request --thread feature-x -- \
  'Fix this task-branch issue only: <file:line and failure>. Re-run <checks>. Report the new commit and exact results. 通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。'
```

After three real attempts with the same blocker, stop looping and report the attempts plus exact error.

### 6. Assign an independent reviewer

The reviewer must be different from the implementer and must not edit the branch:

```bash
hcom send @exact-reviewer --intent request --thread feature-x -- \
  'Review <branch-or-commit> read-only against <acceptance criteria>. Inspect the complete diff and relevant tests. Report only actionable findings as file:line with a concrete failure scenario, or "No issues". Do not edit. 通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。'
```

Route difficult backend, security, or architecture review to Codex. OMP and OpenCode can cross-review ordinary changes.

### 7. Verify and integrate

The coordinator independently checks:

- branch and commit are the ones reported;
- complete diff contains only intended files;
- no secrets, generated noise, or accidental deletions exist;
- required format, lint, type, test, and build commands pass;
- review findings are resolved;
- default branch has been integrated when repository policy requires it.

Use a pull request for protected branches. Never bypass approvals, rulesets, or required checks. If behavior is unclear, work overlaps, conflicts are unsafe, or checks fail, leave the work unmerged and report exact evidence.

### 8. Clean up

Kill only workers started by this coordinator, and only after their work is safely recorded:

```bash
hcom kill exact-worker
```

Never kill pre-existing agents, another coordinator's workers, or agents with uncommitted work. Never use `hcom kill all` in a shared environment.

## Native worker commands and subagents

A worker can run native commands such as a review or debug command only when its tool documents that command. If availability is unknown, ask the worker to list its installed commands or skills first. Never invent a slash command.

A worker may use native subagents for bounded internal tasks. That worker remains responsible for verifying their output and sending one consolidated report. The HCOM coordinator manages the worker, not the worker's private subagents.

Install an extra skill into a worker only when the current task needs it and the source is already trusted. Provision before launching the worker because a running session may not reload skills.

## Common mistakes

- Starting one of every tool before knowing task shape.
- Using Codex for cheap bulk edits or Antigravity for backend-only work.
- Assuming `tool: omp` proves which MiniMax model is active.
- Delegating to a placeholder or stale agent name.
- Sending vague tasks without file ownership or acceptance criteria.
- Letting implementer approve its own change.
- Letting two agents edit the same files concurrently.
- Trusting a worker's “tests passed” claim without checking evidence.
- Reading every full transcript instead of using events and concise reports.
- Killing agents the coordinator did not start.
- Spawning more workers when the real blocker is permission, approval, CI, or branch protection.

## Quick decision card

```text
Default pool       = 1 Codex coordinator + 1 OMP + 1 OpenCode
Simple/bulk        -> Claude
Moderate/long ctx  -> OMP (MiniMax)
Complex impl       -> OpenCode (Qwen)
Frontend/visual    -> Antigravity (Gemini)
Security/hard work -> Codex
Before send        -> hcom list --json
Implementation     -> bounded files + acceptance + checks
Review             -> different agent, read-only
Monitoring         -> hcom events, never sleep loops
Truth              -> verify diff and commands yourself
Cleanup            -> only coordinator-owned agents
```
