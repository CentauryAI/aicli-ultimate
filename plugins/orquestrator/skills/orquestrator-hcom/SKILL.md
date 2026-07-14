---
name: orquestrator-hcom
description: Coordinate multiple AI coding agents through hcom while the current agent acts only as orchestrator. Use when the user asks for Orquestrator/HCOM mode, pure delegation, cross-terminal agent coordination, worker/reviewer pipelines, or a multi-agent SDD workflow.
---

# HCOM Orquestrator

Coordinate work. Do not implement code in this thread while mode is active.

## Start

1. Run `hcom --help`, `hcom status`, then `hcom list`.
2. If no suitable agents exist, ask user before spawning new external agents.
3. State active agents, task split, and merge owner to user.

Use current `hcom` commands. Delegation and monitoring are through hcom.

### Capacity scan

On every user request while mode active:

1. Refresh `hcom list --json` to see current agent state.
2. Derive independent useful roles from the request: investigation, implementation, test analysis, review, or other bounded functions.
3. Match compatible idle agents to those roles using tool-aware routing and CAPS v1 relevant skills/commands. Before assignment, refresh status; if chosen capability is unknown, ask or verify, do not guess. Delegation should name relevant documented skill or native command when useful, not invent.
4. Delegate in parallel only if it materially reduces latency or context usage and file ownership does not overlap.

Idle agents alone are not a reason to invent work. Coordination cost may justify leaving agents idle. Do not spawn or assign agents just because they are available.

**Failure guards**:

1. **Stale state**: Agent idle at scan but busy at dispatch → overload. Guard: re-run `hcom list --json` immediately before each dispatch. Status changed? Skip that agent.
2. **Edit collision**: Two agents write same file (e.g., docs + code both touch README). Guard: reserve file scope per agent in task brief. Agent writes nothing outside its list without coordinator approval.
3. **Busywork masked as productivity**: Agent assigned "research" returns nothing usable. Guard: every role must have verifiable deliverable. Generic or unusable output → mark FAIL, do not re-dispatch.

## Mode lifecycle

Once activated, mode persists for the current conversation until explicit stop.

- Every user request within the conversation: maintain pure delegation and refresh live state (`hcom list --json`) before assignment.
- Explicit stop: `exit orchestrator`, `stop orquestrator`, or `normal mode` ends the mode.
- A new CLI session requires reactivation; mode does not carry over.
- The anti-forget purpose (maintain delegation discipline every turn) is part of the common contract. If a host provides a native hook or plugin surface, an equivalent integration is optional. The common contract does not depend on any specific host mechanism.

## Tool-aware routing

Before every delegation, read `hcom list --json`. HCOM reports each live agent's `name`, `tool`, `status`, and `description`; it does not report the model actually configured behind the tool. Treat these model names as this installation's expected profiles, never as runtime detection.

| Tool | Expected model | Priority and fit | Do not use for |
| --- | --- | --- | --- |
| `claude` | DeepSeek V4 Flash | First choice for cheap, fast, simple, repetitive, or bulk work: renames, mechanical edits, small functions, and straightforward implementations. | Images, visual work, or complex/high-risk reasoning. |
| `omp` | MiniMax M3 | Cheap choice for easy-to-moderate agentic work, long context, and multimodal input. Ships with Perplexity web search, so it is the first choice for live internet research. Good fallback for Claude or OpenCode. | Highest-risk security or architecture decisions. |
| `opencode` | Qwen 3.7 Plus | Moderate-to-complex implementation needing more reasoning than Claude, including multimodal input. | Work that clearly requires maximum-quality security or backend reasoning. |
| `antigravity` | Gemini 3.5 Flash | Frontend, visual, multimodal, image-input, and image-generation tasks. | Backend-only work better handled more cheaply elsewhere. |
| `codex` | GPT-5.6 Sol | Maximum-quality research, planning, difficult backend, optimization, security analysis, and hard final review. | Frontend work. |

Unknown tools have no default capability. Use them only when their live `description` explicitly matches the task.

### Selection order

1. Apply hard exclusions first. Never send image work to Claude or frontend work to Codex.
2. Match required capability and domain. A matching specialist `description` breaks ties but never overrides a hard exclusion.
3. Match complexity: simple/bulk -> Claude; easy-to-moderate, long-context, or live web research -> OMP; moderate-to-complex -> OpenCode; frontend/visual -> Antigravity; complex/high-risk backend, deep offline research, planning, optimization, or security -> Codex.
4. Among valid matches, prefer `listening` over `active`; never assign to `blocked` or stale agents.
5. Among equally valid idle agents, choose the cheapest/fastest profile: Claude, OMP, OpenCode, Antigravity, then Codex.
6. If the preferred tool is unavailable, use only a compatible fallback and state the quality, cost, or modality tradeoff. If no compatible live agent exists, ask before spawning one.

Examples: bulk project rename -> Claude; ordinary API implementation -> OMP or OpenCode according to complexity; live internet research (docs, releases, current facts) -> OMP via Perplexity; screenshot-driven UI -> Antigravity; authentication threat review -> Codex. Split mixed tasks so frontend goes to Antigravity and complex backend/security goes to Codex.

## CAPS v1

Capability card per worker. Exact format:

```
CAPS v1 | name=<hcom_name> | tool=<tool> | session=<session_id> | skills=<relevant_skills> | commands=<native_commands> | source=<how_known> | limits=<known_limits>
```

- Query only the selected worker's relevant capabilities for the current task, not a full enumeration.
- Build on first selected use or when the task needs a native command.
- Cache in coordinator context and in the same HCOM thread, keyed by exact name/tool/session_id.
- After context compaction, recover from thread or events transcript.
- No global filesystem cache.
- session_id empty or changed -> refresh or invalidate the card.
- Unknown capability -> no guess; ask the worker or check documentation.

## Mode gate

Two independent axes:

### Workflow depth: Direct or SDD

| Depth | When |
| --- | --- |
| **Direct** | Bounded, known cause, low risk, few dependent steps. |
| **SDD** | New public behavior, multiple dependent steps or subsystems or implementers, architecture or migration or high risk. Few files can still be SDD if risk or complexity warrants it. |

### Decision gate: none, Deliberation, or Consult

Stackable on either workflow depth.

| Gate | When |
| --- | --- |
| **none** | Approach is clear; proceed with implementation. |
| **Deliberation** | 2+ viable approaches, uncertain tradeoff. |
| **Consult** | Needs human authority, scope, or product choice. |

Risk and ambiguity override file count. When in doubt, escalate depth or add a decision gate.

See `references/sdd-workflow.md` for the full SDD pipeline and gate decision tree.

## Deliberation

When the decision gate is Deliberation:

1. Request independent proposals from 2-3 workers.
2. Collect proposals; each worker proposes independently.
3. One critique pass: a different worker (or the coordinator) critiques all proposals.
4. Advisory vote: workers vote on preferred approach.
5. Coordinator synthesizes proposals, critique, and vote.
6. Coordinator makes routine technical final decision within user authorization.
7. Human makes final decision for material authority, scope, or product choice.

Implementer must not be the read-only reviewer. Review provides advisory evidence; final authority follows this section.

## Command protocol

HCOM syntax changes between versions. The installed CLI is authoritative; the upstream reference is <https://github.com/aannoo/hcom>.

1. Before using a command or flag not shown below, run `hcom <command> --help`. For the full installed reference, run `hcom run docs --cli`.
2. Never guess a launch alias or flag. Run the selected tool's launch help, then use the exact syntax it lists: `hcom [N] <tool> [hcom flags] [tool arguments]`.
3. Read the launch result. Use only names, tags, and batch identifiers HCOM actually returns; confirm readiness with the documented launch result or event command. Never use `sleep`.
4. Refresh `hcom list --json` before assignment because names and status can change.
5. Send a direct task with `hcom send @exact-name -- '<message>'`. Keep every HCOM flag before `--`; message text goes after it.
6. If a command fails validation, preserve the exact error, consult that command's help, and correct it from documented syntax. Do not improvise a replacement command.
7. Include the same help-first rule in worker prompts when workers may call HCOM themselves.
8. Clean up only coordinator-owned agents, using the exact names returned at launch and the cleanup command documented by local help.

## Worker provisioning

The orchestrator may install skills into a worker's tool before delegating, using the `skills` CLI from the terminal:

```bash
npx skills add <owner>/<repo>@<skill> -g -y -a <agent-id>
```

Tool to agent-id map: `claude` -> `claude-code`, `codex` -> `codex`, `opencode` -> `opencode`, `omp` -> `pi`, `antigravity` -> `antigravity-cli`.

1. Install only skills the current task needs, from sources the user already trusts; ask before adding anything else.
2. Provision before launching the worker; a running session may not pick up new skills.
3. Verify the install output reports success for the targeted agent before relying on the skill.

## Worker bootstrap

Pre-existing or bare-launched worker: first task/message MUST contain full compact protocol (scope, files, acceptance, checks, communication contract, standing worker rules). No implicit context from coordinator session.

If user authorizes spawn: first disclose tool/count + compact contract; user authorization suffices, no double approval. Check `hcom <tool> --help`; if `--hcom-system-prompt` listed, use it; otherwise inject via first task message. Don't guess flag.

See `references/handoff-protocol.md` for the per-task handoff template fields.

## Worker commands

Workers execute their own native commands (`/code-review`, `/debug`, and similar) when the delegation message names them:

```bash
hcom send @worker -- 'run /code-review on branch <branch>; report findings as file:line.'
```

Name a command only when the worker's tool documents it; when unsure, first ask the worker to list its available commands/skills. Never invent command names.

## Nested delegation

Workers may spawn their own subagents through their tool's native mechanism to parallelize bounded subtasks. The worker remains accountable: it verifies subagent output before trusting it and reports one consolidated result to the orchestrator through hcom. The orchestrator never manages a worker's subagents directly and never counts unverified subagent claims as done.

## Communication contract

HCOM hooks transport and inject messages; they do not rewrite prose. Style enforcement is a prompt-level protocol, not a formatter hook.

- Worker/orchestrator HCOM messages use Caveman `wenyan-ultra`. Preserve code, commands, paths, identifiers, quoted output, and error text verbatim.
- Orchestrator messages to the human/bigboss use normal concise English.
- Coordinator translates/summarizes worker wenyan to concise normal user language for the human/bigboss. Human never sees raw wenyan.
- Every task, review, follow-up, and nested delegation must include: `通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。`
- If a worker reply breaks this contract, request one reformatted reply with the contract repeated. Do not loop on style after that one retry.
- Coordinator includes its real hcom name in first message to each worker. Workers report to that name, not placeholder `@orchestrator`.

## Peer messaging

Peer messaging only for authorized scope, dependency, or deliberation. Same `--thread`. Target peer + coordinator. No broad broadcast. No overlapping file ownership.

## Standing worker rules

Include these rules in every delegation message:

1. Before implementing, create `WALKTHROUGH.md` on the task branch: intended steps, files to touch, checks to run.
2. Record every non-obvious choice in `DECISIONS.md`: what, why, alternatives rejected.
3. Report exact failing commands and verbatim errors; never summarize failures away.
4. Stay within the assigned file ownership and scope; ask before expanding.
5. Follow repository branch/PR policy; never commit to protected branches.
6. Report dependency status only on state change or block. Never wait silent when blocked.

## Progress reporting

Four progress signals:

1. Ack on task receipt (ETA).
2. Meaningful milestone updates (not timer-based).
3. Blocker request with exact error.
4. Final evidence: branch, commit, files, check results.

No timer spam. Dependency report only on state change or block, not every update.

## Token discipline

Portable rules only:

- One bounded task per agent. Fresh context, no history drag.
- Compact milestone and final evidence. No prose, no filler.
- Archive or compact conversation only when host documents support it. Check host documentation before using archive/compact commands.
- No invented cross-host commands. If host does not document a command, do not use it.

## Contract

- Delegate implementation, investigation, and review through `hcom send`.
- Use terminal only for hcom, worker provisioning (`skills` CLI), read-only inspection, Git coordination, and verification.
- Never edit implementation files in orchestrator thread.
- Never hardcode agent names. Read names from `hcom list` or launch output.
- Monitor with `hcom events`; read full transcripts only when evidence is needed.
- Kill coordinator-owned agents only after work is safely recorded (branch pushed, commit visible, or report received). Never kill pre-existing agents, another coordinator's workers, or agents with uncommitted work.

## Workflow

1. Inspect scope and repository policy.
2. **Capacity scan**: Refresh `hcom list --json`. Derive independent useful roles (investigation, implementation, test analysis, review) from the request. Match compatible idle agents to those roles using tool-aware routing and CAPS v1 relevant skills/commands. Before assignment, refresh status; if chosen capability is unknown, ask or verify, do not guess. Delegate in parallel only if it materially reduces latency/context and file ownership does not overlap. Idle agents alone are not a reason to invent work; coordination cost may justify leaving them idle.
3. Split into independent, bounded tasks with file ownership.
4. Send each worker exact scope, branch, acceptance criteria, checks, and the standing worker rules.
5. Track progress through hcom events. Do not poll with `sleep`.
6. Delegate only task-branch-correctable sync or integration failures, such as code conflicts, back to the original implementer with the exact errors. Have that agent resolve them on the task branch; do not edit in the orchestrator thread.
7. On worker completion signal, assign an independent read-only reviewer who is different from the implementer/resolver. Event-driven: no idle between implement and verify. Review provides advisory evidence; final authority follows Deliberation section.
8. Integrate only after independent review and repository checks pass on the resolved branch.
9. Do not delegate permission failures, missing approvals, required-check failures, ruleset blocks, or other repository-policy failures as merge-resolution work. Report the exact external blocker and leave the pull request unmerged.
10. If the intended combined behavior is unclear, conflicts cannot be resolved safely, or review rejects the result, leave the pull request draft/unmerged and report the exact evidence and decision needed.
11. After GitHub confirms the pull request state is `MERGED`, remove the task branch according to repository policy. Report cleanup failures separately from the merge; never delete a protected or unmerged branch.

For CentauryAI repositories, obey protected-branch policy: `ai/<task>-<id>` branch, PR-only integration, no direct default-branch commits or pushes.

## Messaging

```bash
hcom send @worker -- \
  '任務：<bounded task>。文件：<paths>。驗收：<checks>。通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。失敗則逐字報之。'

hcom send @reviewer -- \
  '審 branch <branch>，準 <acceptance>。唯讀。通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。以 file:line 報疵。'
```

Blocked after three real attempts: send exact attempts and error to coordinator. Do not loop.

## Large work

Use lightweight SDD only when workflow depth is SDD:

`scope -> proposal -> spec -> tasks -> implementation -> independent verification -> PR`

Maintain existing project docs. Create `STATUS.md` only for long/multi-worker/user-requested tasks; otherwise hcom events are enough. Direct mode is lean: no artifacts beyond WALKTHROUGH.md and DECISIONS.md on task branch.

See `references/sdd-workflow.md` for the full pipeline.

## Stop

When user says `exit orchestrator`, `stop orquestrator`, or `normal mode`:

1. Stop pure-delegation constraint.
2. Verify work recorded (branch pushed, commit visible, or report received).
3. Clean up only coordinator-owned agents. Never kill pre-existing agents or agents with uncommitted work.
4. Give final state and return to normal implementation mode.
