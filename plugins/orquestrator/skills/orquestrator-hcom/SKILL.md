---
name: orquestrator-hcom
description: Coordinate multiple AI coding agents through Kore while the current agent acts only as orchestrator. Use when the user asks for Orquestrator/HCOM mode, pure delegation, cross-terminal agent coordination, worker/reviewer pipelines, or a multi-agent SDD workflow.
---

# Kore Orquestrator

Coordinate work. Do not implement code in this thread while mode is active.

## Start

1. Run `kore status`, then `kore list`.
2. If no suitable agents exist, ask user before spawning new external agents.
3. Create one thread id for workflow and pass `--thread <id>` to every message.
4. State active agents, task split, and merge owner to user.

Use current `kore` commands. `hcom` is legacy; do not depend on it.

## Contract

- Delegate implementation, investigation, and review through `kore send`.
- Use terminal only for Kore, read-only inspection, Git coordination, and verification.
- Never edit implementation files in orchestrator thread.
- Never hardcode agent names. Read names from `kore list` or launch output.
- Use `--intent inform` for status, `request` only when reply required, `ack` for receipt.
- Monitor with `kore events`; read full transcripts only when evidence is needed.
- Kill coordinator-owned agents when work completes. Never kill pre-existing agents.

## Workflow

1. Inspect scope and repository policy.
2. Split into independent, bounded tasks with file ownership.
3. Send each worker exact scope, branch, acceptance criteria, and checks.
4. Track progress through Kore events. Do not poll with `sleep`.
5. Give completed work to a different reviewer.
6. Integrate only after review and repository checks pass.
7. Report outcome, failures, branches, PRs, and remaining risk.

For CentauryAI repositories, obey protected-branch policy: `ai/<task>-<id>` branch, PR-only integration, no direct default-branch commits or pushes.

## Messaging

```bash
kore send @worker --thread "$thread" --intent request -- \
  'task: <bounded task>. files: <paths>. acceptance: <checks>. report exact failures.'

kore send @reviewer --thread "$thread" --intent request -- \
  'review branch <branch> against <acceptance>. read-only. report file:line defects.'
```

Blocked after three real attempts: send exact attempts and error to coordinator. Do not loop.

## Large work

Use lightweight SDD only when task needs it:

`scope -> proposal -> spec -> tasks -> implementation -> independent verification -> PR`

Maintain existing project docs. Create `STATUS.md` only when user needs a persistent dashboard; otherwise Kore events are enough.

## Stop

When user says `exit orchestrator`, `stop orquestrator`, or `normal mode`:

1. Stop pure-delegation constraint.
2. Clean up only coordinator-owned agents.
3. Give final state and return to normal implementation mode.
