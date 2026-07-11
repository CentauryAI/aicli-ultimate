---
name: centaury-branch-workflow
description: Enforce the safe CentauryAI Git workflow. Use whenever changing a repository whose GitHub remote owner is CentauryAI (or the legacy CentuaryAI spelling), when starting company work, preparing a pull request, checking for duplicate work, synchronizing with the primary branch, or deciding whether a branch is safe to merge.
---

# CentauryAI branch workflow

Primary branches are protected. Never edit, commit, push, force-push, or merge directly on `main`, `master`, or the remote default branch.

## Before making any change

1. Confirm at least one remote belongs to `CentauryAI` or legacy `CentuaryAI`. If not, use the repository's own workflow.
2. Read repository instructions and inspect the working tree. Preserve existing user changes; do not switch branches with unresolved or unexplained changes.
3. Fetch the remote default branch and determine it from `refs/remotes/<remote>/HEAD`, then fall back to `main` or `master`.
4. Search before duplicating work:
   - inspect the default branch history and current code for the requested behavior;
   - inspect matching remote branches;
   - when `gh` is authenticated, search open and merged pull requests using task identifiers and distinctive keywords.
5. If the work already exists, stop implementation and report the commit, branch, or pull request. Do not create a duplicate branch.
6. Before the first edit, create a fresh branch from the current remote default branch. Use `ai/<short-task>-<short-id>` unless the repository defines another convention.

## While working

- Keep changes scoped to the task. Commit only relevant files.
- Never weaken tests or delete another contributor's work merely to resolve a conflict.
- Do not use force-push unless the user explicitly authorizes it and repository policy permits it.
- Re-check remote pull requests when long-running work may overlap another contributor.

## Before publishing

1. Fetch the remote default branch again.
2. Integrate it into the task branch. Resolve conflicts only when the intended combined behavior is clear. If it is not clear, stop and report each conflict.
3. If the branch has no effective diff because the work landed elsewhere, do not open a duplicate pull request. Report the existing implementation and leave the branch unmerged.
4. Run repository-prescribed formatting, linting, type checks, tests, and build checks. Report literal failures.
5. Review the final diff for secrets, generated noise, accidental deletions, and unrelated changes.

## Pull request and merge

- Push only the task branch and create a pull request targeting the remote default branch.
- Describe scope, tests run, residual risk, and any overlap checked.
- Merge only through the pull request after the branch is conflict-free and all required checks and approvals pass. Prefer GitHub auto-merge with the repository's configured merge method.
- Never bypass branch protection, required reviews, or failing checks.
- If incompatible and no safe resolution is evident, keep the pull request draft/unmerged and add a clear comment listing conflicts, failed checks, attempted fixes, and the decision needed.
- If another pull request already performs the same work, link it, comment on the duplicate when appropriate, and do not merge this branch.

## After merge

1. Confirm GitHub reports the pull request state as `MERGED`; do not infer this from local history alone. Record its head branch, base branch, and `headRefOid` before deleting anything.
2. Verify the head is not the base, default, `main`, `master`, or another protected branch. If the remote ref is absent because GitHub already deleted it, no remote deletion is needed.
3. Delete the remote head atomically with `git push --force-with-lease=refs/heads/<branch>:<headRefOid> <remote> --delete <branch>`. This narrow lease authorizes deletion only while the remote ref still equals the pull request's `headRefOid`; never use it to force-update the branch. On a mismatch, stale lease, or unknown SHA, do not delete it. A repository's automatic GitHub head-branch deletion is also acceptable.
4. If the local task branch remains, switch to another branch and run `git branch -d <branch>`. Never use `git branch -D` to bypass the merged check.
5. Never delete an unmerged branch or a branch whose merge state is unknown. Treat cleanup failure separately from merge failure: keep the successful merge result, report the exact undeleted branch and error, and do not force deletion.

Local hooks are a guardrail, not the authority. GitHub organization rulesets and branch protection are the final enforcement layer.
