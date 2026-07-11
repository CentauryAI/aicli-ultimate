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

## Tool-aware routing

Before every delegation, read `hcom list --json`. HCOM reports each live agent's `name`, `tool`, `status`, and `description`; it does not report the model actually configured behind the tool. Treat these model names as this installation's expected profiles, never as runtime detection.

| Tool | Expected model | Priority and fit | Do not use for |
| --- | --- | --- | --- |
| `claude` | DeepSeek V4 Flash | First choice for cheap, fast, simple, repetitive, or bulk work: renames, mechanical edits, small functions, and straightforward implementations. | Images, visual work, or complex/high-risk reasoning. |
| `omp` | MiniMax M3 | Cheap choice for easy-to-moderate agentic work, long context, and multimodal input. Good fallback for Claude or OpenCode. | Highest-risk security or architecture decisions. |
| `opencode` | Qwen 3.7 Plus | Moderate-to-complex implementation needing more reasoning than Claude, including multimodal input. | Work that clearly requires maximum-quality security or backend reasoning. |
| `antigravity` | Gemini 3.5 Flash | Frontend, visual, multimodal, image-input, and image-generation tasks. | Backend-only work better handled more cheaply elsewhere. |
| `codex` | GPT-5.6 Sol | Maximum-quality research, planning, difficult backend, optimization, security analysis, and hard final review. | Frontend work. |

Unknown tools have no default capability. Use them only when their live `description` explicitly matches the task.

### Selection order

1. Apply hard exclusions first. Never send image work to Claude or frontend work to Codex.
2. Match required capability and domain. A matching specialist `description` breaks ties but never overrides a hard exclusion.
3. Match complexity: simple/bulk -> Claude; easy-to-moderate or long-context -> OMP; moderate-to-complex -> OpenCode; frontend/visual -> Antigravity; complex/high-risk backend, research, planning, optimization, or security -> Codex.
4. Among valid matches, prefer `listening` over `active`; never assign to `blocked` or stale agents.
5. Among equally valid idle agents, choose the cheapest/fastest profile: Claude, OMP, OpenCode, Antigravity, then Codex.
6. If the preferred tool is unavailable, use only a compatible fallback and state the quality, cost, or modality tradeoff. If no compatible live agent exists, ask before spawning one.

Examples: bulk project rename -> Claude; ordinary API implementation -> OMP or OpenCode according to complexity; screenshot-driven UI -> Antigravity; authentication threat review -> Codex. Split mixed tasks so frontend goes to Antigravity and complex backend/security goes to Codex.

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

## Contract

- Delegate implementation, investigation, and review through `hcom send`.
- Use terminal only for hcom, read-only inspection, Git coordination, and verification.
- Never edit implementation files in orchestrator thread.
- Never hardcode agent names. Read names from `hcom list` or launch output.
- Monitor with `hcom events`; read full transcripts only when evidence is needed.
- Kill coordinator-owned agents when work completes. Never kill pre-existing agents.

## Workflow

1. Inspect scope and repository policy.
2. Split into independent, bounded tasks with file ownership.
3. Send each worker exact scope, branch, acceptance criteria, and checks.
4. Track progress through hcom events. Do not poll with `sleep`.
5. Give completed work to a different reviewer.
6. Integrate only after review and repository checks pass.
7. Report outcome, failures, branches, PRs, and remaining risk.

For CentauryAI repositories, obey protected-branch policy: `ai/<task>-<id>` branch, PR-only integration, no direct default-branch commits or pushes.

## Messaging

```bash
hcom send @worker -- \
  'task: <bounded task>. files: <paths>. acceptance: <checks>. report exact failures.'

hcom send @reviewer -- \
  'review branch <branch> against <acceptance>. read-only. report file:line defects.'
```

Blocked after three real attempts: send exact attempts and error to coordinator. Do not loop.

## Large work

Use lightweight SDD only when task needs it:

`scope -> proposal -> spec -> tasks -> implementation -> independent verification -> PR`

Maintain existing project docs. Create `STATUS.md` only when user needs a persistent dashboard; otherwise hcom events are enough.

## Stop

When user says `exit orchestrator`, `stop orquestrator`, or `normal mode`:

1. Stop pure-delegation constraint.
2. Clean up only coordinator-owned agents.
3. Give final state and return to normal implementation mode.
