# DECISIONS — orchestrator-protocol-0714

## D1: Mode lifecycle — conversation-scoped, anti-forget purpose ports

**What**: Mode persists for current conversation until explicit stop. Fresh session requires reactivation.

**Why**: The literal `~/.claude/.orchestrator-mode` flag file and `UserPromptSubmit` hook are not a common dependency of the cross-host skill. However, their anti-forget purpose ports: after skill activation, every user request within the conversation maintains pure delegation and refreshes live state (`hcom list --json`), until explicit stop. A new CLI session requires reactivation. If a host has a native hook or plugin surface, an equivalent integration is optional; the common contract does not depend on it.

**Alternatives rejected**:
- Port literal flag file mechanism → not cross-host; each CLI has different hook/plugin lifecycle.
- Use HCOM `notes` or `hints` → per-agent bootstrap/message-level, not mode lifecycle.
- Environment variable → does not persist across conversation turns in most CLIs.

## D2: CAPS v1 — exact format, targeted query, no filesystem cache

**What**: Capability card with exact format: `CAPS v1 | name=... | tool=... | session=... | skills=... | commands=... | source=... | limits=...`. Only query the selected worker's relevant capabilities, not enumerate all. Build on first selected use or when task needs a native command. Cache in coordinator context + same HCOM thread keyed by exact name/tool/session_id. Recoverable from thread/events transcript after compaction. No global filesystem cache. session_id empty or changed => refresh/invalidate. Unknown => no guess.

**Why**: HCOM reports tool, not model. Coordinator must not assume model from tool. CAPS gives structured capability without pretending to detect runtime state. Session_id invalidation prevents stale card reuse after agent restart. No filesystem cache because capabilities are per-session, not per-installation.

**Alternatives rejected**:
- Runtime model detection → HCOM does not expose this; would be hallucination.
- Static capability table only → does not capture per-worker skills, native commands, or session-specific state.
- Cache indefinitely → session restart changes capabilities; must invalidate.
- Global filesystem cache → contradicts per-session requirement; stale across restarts.

## D3: Mode gate — two axes, not four mutually exclusive modes

**What**: Two axes:
- **Workflow depth** = Direct or SDD.
- **Decision gate** = none / Deliberation / Consult (stackable on Direct/SDD).

**Direct**: bounded, known cause, low risk, few dependent steps.
**SDD**: new public behavior, multiple dependent steps or subsystems or implementers, architecture or migration or high risk. Few files can still be SDD if risk/complexity warrants it.
**Deliberation**: 2+ viable approaches, uncertain tradeoff.
**Consult**: needs human authority, scope, or product choice.

Risk and ambiguity override file count.

**Why**: Original package had "Operation Modes" table but no decision criteria. Coordinator defaulted to subjective judgment, causing inconsistent mode selection. Two axes separate workflow depth from decision authority, allowing stackable combinations (e.g., Direct + Deliberation for a simple task with ambiguous approach).

**Alternatives rejected**:
- Four mutually exclusive modes → cannot combine workflow depth with decision gate.
- `≤3 files` / `>3 files` threshold → does not capture risk, architecture, public behavior, or dependent steps.
- Precedence ordering `Consult>Deliberation>SDD>Direct` → axes are stackable, not ordered.
- Let coordinator decide freely → inconsistent; no audit trail.
- Always SDD → over-engineering for simple tasks.

## D4: Deliberation — proposals → critique → vote → final

**What**: Independent proposals first (2-3 workers) → one critique pass → advisory vote → coordinator synthesizes. Coordinator makes routine technical final decision within user authorization. Human makes final decision for material authority, scope, or product choice. Implementer != read-only reviewer.

**Why**: Original package had "Multi-Agent Voting" but only 2 steps (propose → synthesize). Missing critique and advisory vote means coordinator synthesizes without structured dissent. Full deliberation catches blind spots. Coordinator retains authority for routine technical decisions; human authority required only for material scope/authority/product.

**Alternatives rejected**:
- Coordinator synthesizes proposals alone → single point of failure; no structured challenge.
- Full debate (multiple rounds) → token-heavy; diminishing returns after one critique.
- Skip vote, coordinator decides → loses worker expertise signal.
- Always escalate to human → slows routine technical decisions.

## D5: Peer messaging — authorized scope only, same thread, no broadcast

**What**: Peer messaging only for authorized scope, dependency, or deliberation. Same `--thread`. Target peer + coordinator. No broad broadcast. No overlapping file ownership.

**Why**: Original package mentioned agent-to-agent coordination in `worker-handoff.md` Dependencies but had no thread rule or overlap prevention. Without same-thread rule, peer messages scatter and coordinator loses visibility. Without authorization constraint, peers message freely. Without overlap rule, two workers edit same file.

**Alternatives rejected**:
- Direct peer messaging without coordinator → coordinator loses visibility; cannot resolve conflicts.
- Separate threads per peer pair → coordinator must monitor N threads; token-heavy.
- Allow overlapping edits with merge resolution → merge conflicts waste worker turns.
- Unrestricted peer broadcast → noise; coordinator cannot track.

## D6: Progress reporting — ack/milestone/blocker/final, no timer spam

**What**: Four progress signals:
1. Ack on task receipt (ETA).
2. Meaningful milestone updates (not timer-based).
3. Blocker request with exact error.
4. Final evidence: branch, commit, files, check results.

No timer spam.

**Why**: Original package had completion signal format but no ack or milestone cadence. Workers either spam progress or go silent. "No timer spam" rule prevents meaningless "still working" messages that waste coordinator context tokens.

**Alternatives rejected**:
- Timer-based progress (e.g., every 5 min) → spam; no information content.
- Only final report → coordinator blind during long tasks; cannot detect blockers early.
- Full transcript streaming → token-heavy; coordinator does not need play-by-play.

## D7: Handoff/bootstrap — pre-existing or bare-launched, full compact protocol

**What**: Pre-existing or bare-launched worker: first task/message MUST contain full compact protocol (scope, files, acceptance, checks, communication contract, standing worker rules). No implicit context from coordinator session.

If user authorizes spawn: first disclose tool/count + compact contract; user authorization suffices, no double approval. Check `hcom <tool> --help`; if `--hcom-system-prompt` listed, use it; otherwise inject via first task message. Don't guess flag.

**Why**: Original package assumed workers spawned with `--system` handoff. Pre-existing or bare-launched workers lack that bootstrap. Self-contained first message ensures worker has all needed context. Spawn authorization is a single gate: user approves spawn + contract together, not spawn then contract separately.

**Evidence**: Installed hcom 0.7.23 lists `--hcom-system-prompt <text>` for all five tools. Documentation must still maintain help-first/conditional approach; do not assume future versions retain this flag.

**Alternatives rejected**:
- Assume pre-existing worker has context → worker lacks scope; wastes turns clarifying.
- Send coordinator session transcript → token-heavy; leaks unrelated context.
- Spawn fresh worker for every task → wastes existing worker; contradicts "pre-existing" use case.
- Double approval (spawn then contract) → unnecessary friction; user authorization suffices.
- Hardcode `--hcom-system-prompt` without help check → future version may remove/rename.

## D8: Worker launch — help-first, no separate custom-prompt approval

**What**: Worker launch follows D7 handoff/bootstrap. If `hcom <tool> --help` lists `--hcom-system-prompt`, use it with user-authorized contract. If not listed, inject protocol via first task message. No separate approval step for custom prompt beyond the spawn authorization in D7.

**Why**: D7 already gates spawn authorization with contract disclosure. A separate "custom prompt approval" step is redundant. Help-first ensures flag exists before use.

**Evidence**: Installed hcom 0.7.23 lists `--hcom-system-prompt <text>` for all five tools. Documentation must still maintain help-first/conditional approach; do not assume future versions retain this flag.

**Alternatives rejected**:
- Separate approval for custom prompt → redundant; D7 spawn authorization covers it.
- Assume flag name → HCOM syntax changes; help-first rule prevents hallucination.
- Hardcode flag without help check → future version may remove/rename.

## D9: Real coordinator name in first worker message

**What**: Coordinator includes its real hcom name in first message to each worker. Workers report to that name, not placeholder `@orchestrator`.

**Why**: Original package had this rule (`orquestrator-hcom.md` L286-305). Workers with `@orchestrator` placeholder cannot route reports. Real name ensures correct routing.

**Alternatives rejected**:
- Use placeholder `@orchestrator` → worker cannot resolve name; reports fail.
- Coordinator tells name verbally → worker may forget; must be in first message.

## D10: Dependency report — state change or block only

**What**: Workers report dependency status only on state change or block. Not every progress update. Never wait silent when blocked.

**Why**: Original package had this in `worker-handoff.md` Dependencies. Without it, worker blocks silently; coordinator cannot intervene. However, repeating dependency status every update is noise; only changes matter.

**Alternatives rejected**:
- Worker waits silently → coordinator blind; task stalls.
- Worker reports only at completion → too late; coordinator cannot reassign.
- Report dependency every update → noise; no new information.

## D11: Event-driven independent reviewer — advisory, not final

**What**: Reviewer triggered on worker completion signal, not on timer. Reviewer is different from implementer. Read-only. Review provides advisory evidence. Coordinator/human retains final authority as in D4.

**Why**: Original package had this (`orquestrator-instructions.md` Event-Driven Verify, `sdd-pipeline/README.md` Phase 7). Timer-based review wastes idle time or triggers prematurely. Completion signal ensures review starts exactly when implementation is ready. Implementer must not approve own work. Reviewer is advisory; final authority follows D4 (coordinator for routine technical, human for material scope/authority/product).

**Alternatives rejected**:
- Timer-based review → may trigger before completion or waste idle time.
- Coordinator reviews → violates separation; implementer should not approve own work.
- Skip review → unverified work reaches PR.
- Reviewer has final authority → contradicts D4 authority model.

## D12: Conditional STATUS.md / SDD artifacts — follow depth, not deliberation

**What**: Artifacts follow SDD workflow depth, long multi-worker tasks, or explicit user request. Deliberation does not automatically create artifacts. Direct mode is lean: no artifacts beyond WALKTHROUGH.md and DECISIONS.md on task branch.

**Why**: Original package had STATUS.md as always-on. For small tasks, STATUS.md overhead exceeds value. Artifact creation follows workflow depth (SDD implies artifacts; Direct does not), not decision gate (Deliberation is a decision mode, not a documentation trigger).

**Alternatives rejected**:
- Always create STATUS.md → overhead for simple tasks.
- Never create STATUS.md → large tasks lose dashboard.
- Always full SDD → over-engineering.
- Deliberation auto-creates artifacts → deliberation is decision mode, not documentation trigger.

## D13: Safe owned-agent cleanup

**What**: Kill only coordinator-owned agents. Verify work recorded (branch pushed, commit visible, or report received) before kill. Never kill pre-existing agents, another coordinator's workers, or agents with uncommitted work.

**Why**: Original package had basic cleanup. Strengthened rules prevent data loss (uncommitted work) and accidental kill of shared agents.

**Alternatives rejected**:
- Kill immediately on task completion → may lose uncommitted work.
- Kill all agents → destroys pre-existing agents; breaks other coordinators.
- Never kill → zombie agents accumulate; waste tokens.

## D14: Compact single-source reference files — SKILL lean

**What**: Create `references/handoff-protocol.md` (worker handoff contract + per-task template fields: goal, scope/files/ownership, acceptance, checks, constraints, dependencies/peers, report format, branch/commit rules, exact communication contract) and `references/sdd-workflow.md` (SDD pipeline + two-axis mode gate). SKILL.md references these instead of inlining. Keep SKILL lean; do not target a specific line count like 250-300.

**Why**: SKILL.md is 153 lines and will grow with new sections. Inlining all contracts makes SKILL.md unwieldy. Reference files are single-source: update once, all consumers get update. Cross-host workers can receive reference file content in handoff without coordinator re-explaining. SKILL should be as lean as correct, not a target length.

**Alternatives rejected**:
- Inline everything in SKILL.md → too long; hard to maintain.
- Separate docs per host → duplication; drift.
- No reference files → SKILL.md becomes monolith.
- Target specific line count → correctness over length.

## D15: Test assertions — real install paths, not physical copies

**What**: Extend `tests/test.sh` to assert:
- References distributed through real host integration paths: `.claude`, shared `.agents` (OpenCode/OMP and applicable Codex), `.gemini`, and Codex native-plugin packaging/install path when selected.
- SKILL.md contains mode lifecycle, CAPS v1, two-axis mode gate, deliberation, peer messaging, progress reporting, handoff/bootstrap.
- Per-host activation/contract assertions where harness permits.
- Negative: common installed skill has no hard dependency/path to Claude flag/hook (`~/.claude/.orchestrator-mode`, `UserPromptSubmit` hook config). Documentation may mention `UserPromptSubmit` historically.

Do NOT assert 5 physical copies.

**Why**: Existing tests assert orquestrator skill presence and some content (L278-328). New content needs assertions to prevent regression. Real install paths reflect actual installer behavior, not an abstract "5 copies" count. Negative assertions prevent Claude-only concepts from becoming hard dependencies in the cross-host skill.

**Alternatives rejected**:
- Assert 5 physical copies → does not reflect actual installer paths.
- No new tests → regression risk; no verification of new concepts.
- Manual verification → not reproducible; missed in CI.
- Negative test bans all mention of `UserPromptSubmit` → too strict; historical documentation mention is acceptable.

## D16: Language contract — coordinator translates wenyan to concise normal bigboss language

**What**: Worker/orchestrator HCOM messages use Caveman wenyan-ultra. Coordinator translates/summarizes worker wenyan to concise normal user language for bigboss. Human never sees raw wenyan.

**Why**: Original package had dual-language protocol. Cross-host, the contract must be explicit: wenyan for worker/orchestrator HCOM channel, concise normal language for human reports.

**Alternatives rejected**:
- Workers write normal English → wastes tokens; breaks caveman efficiency.
- Coordinator forwards raw wenyan to human → human must decode.

## D17: Portable token discipline — concrete only

**What**: Token discipline rules port only when concrete and cross-host:
- One task per fresh agent.
- Compact evidence in reports.
- Archive/compact when host supports it.

No invented cross-host commands. No host-specific token mechanisms.

**Why**: Original package had extensive token strategy (auto-compact env vars, haiku model, etc.). Those are host-specific and do not port. Only concrete, host-agnostic discipline ports.

**Alternatives rejected**:
- Port all token strategy → includes host-specific mechanisms.
- No token discipline → wastes tokens.
- Invent cross-host commands → hallucination.
