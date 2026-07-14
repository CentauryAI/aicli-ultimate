# Handoff Protocol Reference

Per-task handoff template fields for worker delegation.

## Required fields

Every task delegation MUST include:

| Field | Description |
|-------|-------------|
| **goal** | What the task achieves (one sentence). |
| **scope/files/ownership** | Exact file paths the worker owns. No overlap with other workers. |
| **acceptance** | Observable result that proves task is done. |
| **checks** | Exact commands to verify acceptance (tests, lint, build). |
| **constraints** | Hard limits: no scope creep, no protected branch commits, no secrets. |
| **dependencies/peers** | Other workers this task depends on, or peers to coordinate with. |
| **report format** | How worker reports progress and completion (see Progress reporting in SKILL.md). |
| **branch/commit rules** | Task branch name, conventional commit format. |
| **communication contract** | Caveman wenyan-ultra for HCOM messages. Coordinator translates to human. |

## Template

```
Task: <goal>
Branch: <task-branch>
Files owned: <paths>
Acceptance: <observable result>
Checks: <exact commands>
Constraints: <hard limits>
Dependencies: <peer workers or none>
Report: ack → milestone → blocker/final (see Progress reporting)
Commit: <type>(<scope>): <summary>

通信：凡 worker/orchestrator 消息，用 Caveman wenyan-ultra；code、commands、paths、identifiers、output、errors，逐字保之。
```

## Bootstrap variants

### Pre-existing or bare-launched worker

First task/message MUST contain full compact protocol (all fields above). No implicit context from coordinator session.

### User-authorized spawn

1. Disclose tool/count + compact contract to user.
2. User authorization suffices (no double approval).
3. Check `hcom <tool> --help`; if `--hcom-system-prompt` listed, use it.
4. Otherwise inject protocol via first task message.
5. Don't guess flag.

## Real coordinator name

Coordinator includes its real hcom name in first message to each worker. Workers report to that name, not placeholder `@orchestrator`.
