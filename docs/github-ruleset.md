# CentauryAI GitHub ruleset

Local hooks prevent common mistakes but can be bypassed. Enforce the policy server-side with a GitHub organization ruleset targeting every repository's default branch.

Recommended settings:

- restrict deletions and force pushes;
- require a pull request before merging;
- require at least one approval and dismiss stale approvals after new commits;
- require conversation resolution;
- require status checks to pass and branches to be up to date;
- block direct updates to the default branch;
- allow only designated release or organization administrators to bypass, and require a reason;
- enable merge queue where repositories have reliable CI;
- enable secret scanning, push protection, and dependency review where available.

Configure required status-check names per repository after CI exists. A nonexistent required check can block every pull request.

The Codex workflow should create a task branch, open a pull request, wait for checks and approvals, and request auto-merge. It must leave incompatible or duplicate work unmerged with an explanatory comment.
