# SDD Workflow Reference

Spec-Driven Development pipeline and mode gate decision tree.

## Two-axis mode gate

### Axis 1: Workflow depth

| Depth | When |
|-------|------|
| **Direct** | Bounded, known cause, low risk, few dependent steps. |
| **SDD** | New public behavior, multiple dependent steps/subsystems/implementers, architecture/migration/high risk. Few files can still be SDD if risk or complexity warrants it. |

### Axis 2: Decision gate

Stackable on either workflow depth.

| Gate | When |
|------|------|
| **none** | Approach is clear; proceed with implementation. |
| **Deliberation** | 2+ viable approaches, uncertain tradeoff. |
| **Consult** | Needs human authority, scope, or product choice. |

Risk and ambiguity override file count.

## SDD pipeline phases

When workflow depth is SDD:

```
scope → proposal → spec → tasks → implementation → independent verification → PR
```

### Phase details

1. **Scope**: Define what needs to change and why. Identify affected files and subsystems.
2. **Proposal**: If decision gate is Deliberation, request 2-3 independent proposals from workers. Otherwise, coordinator proposes approach.
3. **Spec**: Write Given-When-Then scenarios or equivalent acceptance criteria. Save in project docs.
4. **Tasks**: Split into atomic independent tasks with file ownership. Each task = one bounded unit.
5. **Implementation**: Assign workers. Each worker owns specific files. No overlap.
6. **Independent verification**: On completion signal, assign read-only reviewer (different from implementer). Event-driven: no idle between implement and verify.
7. **PR**: Integrate only after review passes and repository checks pass.

## Conditional artifacts

| Artifact | When |
|----------|------|
| **WALKTHROUGH.md** | Always (on task branch). |
| **DECISIONS.md** | Always (on task branch). |
| **STATUS.md** | Only for long/multi-worker/user-requested tasks. |
| **Spec/design docs** | Only for SDD workflow depth. |

Direct mode is lean: no artifacts beyond WALKTHROUGH.md and DECISIONS.md on task branch.

## Deliberation flow

When decision gate is Deliberation:

1. Independent proposals from 2-3 workers.
2. One critique pass (different worker or coordinator).
3. Advisory vote.
4. Coordinator synthesizes.
5. Coordinator makes routine technical final decision within user authorization.
6. Human makes final decision for material authority/scope/product choice.

Implementer must not be the read-only reviewer.
