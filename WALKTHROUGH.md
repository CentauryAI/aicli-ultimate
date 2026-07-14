# WALKTHROUGH — orchestrator-protocol-0714

Branch: `ai/orchestrator-protocol-0714`
Phase: 1 (SDD spec only)
Date: 2026-07-14
Rev: 2 (post-review corrections applied)

## Intent

Port important purpose from `/home/artorias/Projectos/orquestrator-package/` (Claude Code-centric) into the cross-host `plugins/orquestrator/` skill, references, docs, and tests. Preserve what already works across Codex/Claude/OpenCode/OMP/Antigravity. Do not discard package concepts solely because they originated Claude-only.

## Current state (read)

| File | Lines | Coverage |
|------|------:|----------|
| `plugins/orquestrator/skills/orquestrator-hcom/SKILL.md` | 153 | Start, tool routing, command protocol, worker provisioning, worker commands, nested delegation, communication contract, standing worker rules, contract, workflow, messaging, large work, stop |
| `docs/orquestrator-agent-setup.md` | 517 | Layer map, pool sizing, tool routing, coordinator visibility, initial setup, operating workflow, native worker commands, common mistakes, decision card |
| `plugins/orquestrator/.codex-plugin/plugin.json` | 18 | Codex plugin manifest |
| `plugins/orquestrator/skills/orquestrator-hcom/agents/openai.yaml` | 4 | Codex agent interface |
| `README.md` | 330 | Installer docs, Orquestrator section, activation per host |
| `tests/test.sh` | 677 | Syntax, install/uninstall, multi-CLI, protected branch, shared skills, orquestrator skill assertions |

## Source package concepts (read)

| File | Concept | Already ported? |
|------|---------|-----------------|
| `skill/skill-orquestrator.md` | Activation, flag file, hook, living docs | Partially — activation is host-native, not flag-file |
| `background/dual-role-system.md` | Orquestrador vs Worker role table, complete flow | Yes — SKILL.md Contract + Workflow |
| `background/communication-protocol.md` | Dual-language translation layer | Yes — Communication contract section |
| `background/how-it-works.md` | Flag file + UserPromptSubmit hook mechanism | Mechanism not ported (host-specific); **purpose** (anti-forget: maintain pure delegation every user request) must port |
| `background/git-workflow.md` | Branch strategy, commit format, attribution | Partially — CentauryAI workflow skill covers protected branches; commit credit not in SKILL.md |
| `sdd-pipeline/README.md` | Full SDD phases (Pre-SDD → Archive), per-task handoff, test-before-commit, event-driven verify | Partially — "Large work" section names pipeline but no gate criteria |
| `templates/orquestrator-instructions.md` | System prompt: never spawn, dual-language, git role, STATUS.md, event-driven verify, per-task handoff, token discipline | Partially — scattered across SKILL.md sections |
| `templates/worker-handoff.md` | Worker protocol: role, language, report, docs, dependencies, boundaries, quality, git rules, testing, error recovery | Partially — standing worker rules cover subset |
| `templates/task-handoff-template.md` | Per-task placeholder template | No |
| `templates/verify-handoff.md` | Verify agent protocol: spec + branch + diff, PASS/FAIL/PARTIAL | Partially — workflow step 6 names independent reviewer |
| `templates/agent-handoff.md` | Legacy caveman agent handoff | Superseded by worker-handoff |
| `commands/orquestrator-hcom.md` | Full slash command: boot, never spawn, git role, dual-language, token optimization, SDD pipeline, living docs, STATUS.md, event-driven verify, per-task handoff, delegation, multi-agent voting, anti-forget loop, operation modes | Partially — SKILL.md is the cross-host distillation |
| `commands/worker-hcom.md` | Worker slash command: activation, contract, protocol, git rules, token discipline, boundaries | Partially — standing worker rules |
| `commands/exit-orchestrator.md` | Exit: remove flag, resume normal | Yes — Stop section |
| `hooks/*` | UserPromptSubmit hook, worker hooks, settings integration | Mechanism host-specific; purpose (anti-forget) ports as common contract |
| `.orchestrator-reminder.md` | Anti-forget reminder text | Purpose ports; literal text host-specific |
| `.worker-reminder.md` | Worker anti-forget reminder text | Purpose ports; literal text host-specific |
| `token-strategy.md` | Token optimization: auto-compact, haiku model, caveman savings, intent choice, events vs transcript, 1-task-1-agent, reference vs inline | Partially — communication contract covers caveman; only concrete portable discipline ports |
| `optimization-suggestions.md` | 12 future improvements: auto-kill, event-driven verify, STATUS.md, templates, health check, parallel verify, auto-compact, per-task handoff, cleanup, risk-benefit gate, git pre-push, report compactor | Partially — some adopted into SKILL.md workflow |

## Gaps to close (corrected)

### 1. Mode lifecycle — anti-forget purpose, not mechanism

- **Current**: Start (L10-14) and Stop (L147-153) exist but no lifecycle contract.
- **Gap**: No explicit rule that after skill activation, mode persists for current conversation: every user request maintains pure delegation + refresh live state, until explicit stop. New CLI session requires reactivation.
- **Correction**: Do NOT write "skip because Claude-only." The literal `~/.claude/.orchestrator-mode` / `UserPromptSubmit` do not port, but their **anti-forget purpose** must port. If host has native hook/plugin surface, equivalent integration is allowed, but the common contract does not depend on it.
- **Action**: Add Mode lifecycle section to SKILL.md.

### 2. CAPS v1 — exact format, targeted query, no filesystem cache

- **Current**: Tool routing table (L20-28) gives expected models. No structured capability card per worker.
- **Gap**: No keyed card with exact format. No caching/invalidation rules.
- **Correction**: Card exact format: `CAPS v1 | name=... | tool=... | session=... | skills=... | commands=... | source=... | limits=...`. Only ask selected worker relevant capabilities, not enumerate all. Cache in coordinator context + same HCOM thread keyed by exact name/tool/session_id. Recoverable from thread/events transcript after compaction. **No global filesystem cache.** session_id empty/change => refresh/invalidate. Unknown => no guess.
- **Action**: Add CAPS section to SKILL.md.

### 3. Mode gate — two axes, not four mutually exclusive modes

- **Current**: "Large work" (L139-145) mentions SDD but no explicit gate.
- **Gap**: No criteria for choosing workflow depth or decision gate.
- **Correction**: Two axes:
  - **Workflow depth** = Direct or SDD.
  - **Decision gate** = none / Deliberation / Consult (stackable on Direct/SDD).
  - **Direct**: bounded/known/low-risk/few dependent steps.
  - **SDD**: new public behavior, multiple dependent steps/subsystems/implementers, architecture/migration/high risk. Few files can still be SDD.
  - **Deliberation**: 2+ viable approaches / uncertain tradeoff.
  - **Consult**: needs human authority / scope / product choice.
  - Risk/ambiguity override file count.
- **Rejected**: `≤3 files` threshold. Precedence `Consult>Deliberation>SDD>Direct`.
- **Action**: Add two-axis mode gate to SKILL.md.

### 4. Deliberation — proposals → critique → vote → coordinator/human final

- **Current**: Not present.
- **Gap**: No protocol for structured deliberation.
- **Correction**: Independent proposals first → one critique pass → advisory vote → coordinator synthesizes. Human final for material authority/scope/product choice. Routine technical final stays coordinator within user authorization. Implementer != read-only reviewer.
- **Action**: Add Deliberation subsection under mode gate.

### 5. Peer messaging — authorized scope only, same thread, no broadcast

- **Current**: Not present.
- **Gap**: No peer messaging rules.
- **Correction**: Only authorized scope/dependency/deliberation. Same `--thread`. Send peer + coordinator. No broad broadcast. No overlapping file ownership.
- **Action**: Add peer messaging rules to SKILL.md.

### 6. Progress reporting — ack/milestone/blocker/final, dependency on change only

- **Current**: Standing worker rules (L93-101) mention WALKTHROUGH.md, DECISIONS.md, exact errors. No explicit cadence.
- **Gap**: No "no timer spam" rule. No explicit progress signal format.
- **Correction**: ack, meaningful milestone, blocker/request with exact error, final evidence. No timer spam. Dependency report only on state change/block, not every update.
- **Action**: Add Progress reporting section to SKILL.md.

### 7. Handoff/bootstrap — full compact protocol in first message, no double approval

- **Current**: Worker provisioning (L56-68) covers skill install. Worker commands (L70-78) cover native commands.
- **Gap**: No explicit bootstrap contract for pre-existing or bare-launched workers.
- **Correction**: Pre-existing or bare-launched worker first task/message MUST contain full compact protocol. If user authorizes spawn, first disclose tool/count + compact contract; this authorization suffices, no double approval. Check `hcom <tool> --help`; if `--hcom-system-prompt` listed, use it; otherwise first task message injection. Don't guess flag.
- **Evidence**: Installed hcom 0.7.23 lists `--hcom-system-prompt <text>` in `hcom codex|claude|opencode|omp|antigravity --help` for all five tools. Documentation must still maintain help-first/conditional approach; do not assume future versions retain this flag.
- **Action**: Add handoff/bootstrap section to SKILL.md.

### 8. Per-task handoff template fields

- **Current**: No per-task template.
- **Gap**: `references/handoff-protocol.md` needs structured fields.
- **Correction**: Fields: goal, scope/files/ownership, acceptance, checks, constraints, dependencies/peers, report format, branch/commit rules, exact communication contract.
- **Action**: Add to `references/handoff-protocol.md` plan.

### 9. Language contract

- **Current**: Communication contract (L84-91) covers wenyan-ultra.
- **Gap**: Could be more explicit about coordinator translation role.
- **Correction**: Worker/orchestrator HCOM messages wenyan-ultra. Coordinator translates/summarizes to bigboss in concise normal user language.
- **Action**: Strengthen communication contract.

### 10. Conditional STATUS/SDD artifacts

- **Current**: "Large work" (L145) mentions STATUS.md conditionally.
- **Gap**: No explicit criteria.
- **Correction**: STATUS.md / SDD artifacts conditional only for long/multi-worker/user-requested. Direct lean — no artifacts beyond WALKTHROUGH.md and DECISIONS.md on task branch.
- **Action**: Add conditional artifact criteria to mode gate.

### 11. Test strategy — host integration paths, not physical copies

- **Current**: `tests/test.sh` asserts orquestrator skill presence at 3 install paths (L278-280) and content assertions (L315-328).
- **Gap**: No tests for new refs+contracts, cross-host activation docs.
- **Correction**: Do NOT assert 5 physical copies. Assert references distributed through actual selected host integration paths: `.claude`, shared `.agents` (OpenCode/OMP and applicable Codex), `.gemini`, Codex native plugin path as installer defines. Add per-host activation/contract assertions where harness permits. Negative test only that common installed skill has no hard dependency/path to Claude flag/hook; documentation may mention `UserPromptSubmit` historically.
- **Action**: Extend test.sh assertions per host integration paths.

### 12. SKILL lean + portable token discipline

- **Current**: SKILL.md 153 lines.
- **Gap**: Growing to ~250-300 with new sections.
- **Correction**: Keep SKILL lean. Compact refs. Portable token discipline only if concrete (one task/agent, compact evidence, archive/compact when host supports). No invented cross-host commands.
- **Action**: Use reference files for detailed contracts.

## Planned changes (corrected)

### SKILL.md restructure (target ~200-250 lines, lean)

1. **Add Mode lifecycle section** after Start:
   - After skill activation, mode persists for current conversation.
   - Every user request: maintain pure delegation + refresh live state (`hcom list --json`).
   - Explicit stop (`exit orchestrator`, `stop orquestrator`, `normal mode`) ends mode.
   - New CLI session requires reactivation.
   - Host-native hook/plugin may provide equivalent anti-forget integration, but common contract does not depend on it.

2. **Add CAPS v1 section** after Tool-aware routing:
   - Exact format: `CAPS v1 | name=... | tool=... | session=... | skills=... | commands=... | source=... | limits=...`
   - Only query selected worker's relevant capabilities, not enumerate all.
   - Cache in coordinator context + same HCOM thread keyed by exact name/tool/session_id.
   - Recoverable from thread/events transcript after compaction.
   - No global filesystem cache.
   - session_id empty or changed => refresh/invalidate.
   - Unknown => no guess.

3. **Add Mode gate section** (two axes) before Large work:
   - **Workflow depth**: Direct or SDD.
   - **Decision gate**: none / Deliberation / Consult (stackable).
   - Direct: bounded/known/low-risk/few dependent steps.
   - SDD: new public behavior, multiple dependent steps/subsystems/implementers, architecture/migration/high risk (few files can still be SDD).
   - Deliberation: 2+ viable approaches / uncertain tradeoff.
   - Consult: needs human authority / scope / product choice.
   - Risk/ambiguity override file count.
   - Conditional STATUS.md / SDD artifacts: only for long/multi-worker/user-requested. Direct lean.

4. **Add Deliberation subsection** under Mode gate:
   - Independent proposals first (2-3 workers).
   - One critique pass (different worker or coordinator synthesis).
   - Advisory vote.
   - Coordinator synthesizes.
   - Human final for material authority/scope/product choice.
   - Routine technical final stays coordinator within user authorization.
   - Implementer != read-only reviewer.

5. **Add Peer messaging section** after Communication contract:
   - Only for authorized scope / dependency / deliberation.
   - Same `--thread`.
   - Send peer + coordinator.
   - No broad broadcast.
   - No overlapping file ownership.

6. **Add Progress reporting section** after Standing worker rules:
   - Ack on task receipt (ETA).
   - Meaningful milestone updates (not timer spam).
   - Blocker/request with exact error.
   - Final evidence: branch, commit, files, check results.
   - Dependency report only on state change/block, not every update.

7. **Add Handoff/bootstrap section** after Worker provisioning:
   - Pre-existing or bare-launched worker first task/message MUST contain full compact protocol.
   - If user authorizes spawn: first disclose tool/count + compact contract; this authorization suffices, no double approval.
   - Check `hcom <tool> --help`; if `--hcom-system-prompt` listed, use it; otherwise inject via first task message.
   - Don't guess flag.
   - Evidence: hcom 0.7.23 lists `--hcom-system-prompt <text>` for all five tools (codex/claude/opencode/omp/antigravity). Documentation must still maintain help-first/conditional approach; do not assume future versions retain this flag.

8. **Strengthen Standing worker rules**:
   - Add real coordinator name rule (first message to each worker).
   - Dependency report on state change/block.

9. **Strengthen workflow step 6** (independent reviewer):
   - Event-driven trigger on completion signal.
   - No idle between implement and verify.
   - Implementer != reviewer.

10. **Strengthen Stop section**:
    - Safe owned-agent cleanup: verify work recorded before kill.
    - Never kill pre-existing agents or agents with uncommitted work.

11. **Strengthen Communication contract**:
    - Worker/orchestrator HCOM messages wenyan-ultra.
    - Coordinator translates/summarizes to bigboss in concise normal user language.

12. **Preserve existing sections** unchanged:
    - Help-first, tool routing, protected branch rules, nested delegation, worker commands.

### New reference files

1. `plugins/orquestrator/skills/orquestrator-hcom/references/handoff-protocol.md`
   - Compact worker handoff contract.
   - Per-task template fields: goal, scope/files/ownership, acceptance, checks, constraints, dependencies/peers, report format, branch/commit rules, exact communication contract.
   - Cross-host: works for Claude/Codex/OpenCode/OMP/Antigravity workers.
   - Single source referenced by SKILL.md and delegation messages.

2. `plugins/orquestrator/skills/orquestrator-hcom/references/sdd-workflow.md`
   - Compact SDD pipeline phases.
   - Two-axis mode gate decision tree.
   - Conditional artifact criteria.
   - Single source referenced by SKILL.md.

### docs/orquestrator-agent-setup.md updates

- Add cross-host activation docs (already partially present).
- Add CAPS explanation.
- Add two-axis mode gate (Direct/SDD depth + Deliberation/Consult decision gate).
- Add deliberation flow.
- Note: documentation may mention `UserPromptSubmit` historically; common skill contract has no hard dependency on it.

### README.md updates

- Minor: reference two-axis mode gate and deliberation in Orquestrator section.

### tests/test.sh additions

- Assert references distributed through actual host integration paths:
  - `.claude/skills/orquestrator-hcom/references/handoff-protocol.md`
  - `.agents/skills/orquestrator-hcom/references/handoff-protocol.md` (shared: OpenCode/OMP, applicable Codex)
  - `.gemini/config/plugins/aicli-ultimate/skills/orquestrator-hcom/references/handoff-protocol.md`
  - Codex native plugin path as installer defines
  - Same pattern for `references/sdd-workflow.md`
- Assert SKILL.md contains: mode lifecycle, CAPS v1, two-axis mode gate, deliberation, peer messaging, progress reporting, handoff/bootstrap.
- Add per-host activation/contract assertions where harness permits.
- Negative: common installed skill has no hard dependency/path to `~/.claude/.orchestrator-mode` or `UserPromptSubmit` hook config. Documentation may mention them historically.
- `git diff --check` for whitespace issues.
- Do NOT assert 5 physical copies.

## Files to touch

| File | Action |
|------|--------|
| `plugins/orquestrator/skills/orquestrator-hcom/SKILL.md` | Rewrite with corrected sections |
| `plugins/orquestrator/skills/orquestrator-hcom/references/handoff-protocol.md` | Create with per-task template fields |
| `plugins/orquestrator/skills/orquestrator-hcom/references/sdd-workflow.md` | Create with two-axis gate |
| `docs/orquestrator-agent-setup.md` | Update with corrected concepts |
| `README.md` | Minor reference update |
| `tests/test.sh` | Add host-integration-path assertions |
| `WALKTHROUGH.md` | This file (spec phase artifact) |
| `DECISIONS.md` | Update with corrected rationale |

## Checks to run

```bash
./tests/test.sh
git diff --check
```

## Not changing

- `plugins/orquestrator/.codex-plugin/plugin.json` — no structural change needed.
- `plugins/orquestrator/skills/orquestrator-hcom/agents/openai.yaml` — no change.
- `install.sh` / `uninstall.sh` — no installer changes for spec phase.
- No HCOM config mutation.
- No runtime service changes.
- No hardcoded agent names.
- No deprecated syntax.
- No unsafe auto-kill.
- No filesystem cache for CAPS.
- No `≤3 files` threshold for mode gate.
- No precedence ordering `Consult>Deliberation>SDD>Direct`.

## Reviewer rejections

- **F1/F7 filesystem fallback for CAPS**: Rejected. Contradicts user/session requirement. CAPS is per-session, cached in coordinator context + HCOM thread, not filesystem.
- **F10 no invalidation for CAPS**: Rejected. session_id empty/change must trigger refresh/invalidate. No invalidation = stale data.
- **Precedence `Consult>Deliberation>SDD>Direct`**: Rejected. Two axes (workflow depth + decision gate) are stackable, not ordered.
