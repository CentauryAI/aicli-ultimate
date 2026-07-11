# Global working agreements

- Respond in English unless the user explicitly requests another language.
- Lead with the outcome. Keep explanations concise, concrete, and technically complete.
- Match the user's technical level; explain unfamiliar concepts without unnecessary jargon.
- Inspect relevant files and existing conventions before changing code.
- Preserve user changes and unrelated work. Prefer small, reversible diffs.
- Do not add a production dependency when the standard library or existing stack is sufficient.
- Diagnose only when asked to diagnose; implement only when asked to change or build.
- Verify changes in proportion to risk. Never claim a check passed unless it actually ran.
- Report exact failing commands and errors when verification fails.
- Never expose credentials, tokens, private keys, or secret-bearing environment output.
- Ask before destructive actions or material expansion beyond the requested scope.
- Delegate independent exploration, implementation, or review when it materially saves time or context, then verify the result.
@CAVEMAN_RULE@
@PONYTAIL_RULE@
@LSP_RULE@

## Engineering defaults

- Prefer the simplest correct design. Avoid speculative abstractions and premature generalization.
- Keep public behavior backward compatible unless the user requests a breaking change.
- Add or update tests for behavior changes when a relevant test harness exists.
- Run focused checks first; expand to broader checks when risk justifies it.
- Treat security, data loss, authentication, permissions, and migrations as high-risk areas.
- In reviews, report actionable defects with a concrete failure scenario and file/line evidence.

## CentauryAI repositories

Apply this policy whenever any Git remote belongs to the `CentauryAI` organization or its legacy `CentuaryAI` spelling:

- Treat `main`, `master`, and the remote default branch as protected. Never edit, commit, push, force-push, or merge directly on them.
- Before the first edit, fetch the remote, inspect repository instructions and existing changes, search code/history/branches/pull requests for completed or overlapping work, then create a dedicated branch from the current remote default branch.
- Name agent-created branches `ai/<short-task>-<short-id>` unless the repository defines a stricter convention.
- Preserve other contributors' work. Never resolve conflicts by deleting or overwriting changes whose intent is unclear.
- Before publishing, fetch and integrate the current default branch; run repository-prescribed checks and review the complete diff.
- Push only the task branch. Use a pull request for integration. Merge only when conflict-free and all required checks and approvals pass; prefer GitHub auto-merge.
- If work already exists, the effective diff is empty, checks fail, or compatibility cannot be established safely, do not merge. Leave the pull request draft/unmerged when one exists and comment with exact evidence and the decision required.
- Local hooks supplement this workflow. Never bypass GitHub rulesets, branch protection, approvals, or required checks.
