---
name: pr-copy-to-main-autonomous
description: Copy file changes from an existing PR onto a new timestamped branch from a target branch, push the branch, and optionally create a new PR through GitHub API. Use when user asks to replicate PR changes onto another branch with a timestamped branch.
---

# PR Copy To Target Branch Autonomous

Use this skill when the user asks to:
- copy changes from an existing PR (for example `#1686`),
- create a new branch from a target branch with a timestamp suffix,
- push all copied file changes,
- and optionally create a new PR targeting a specific branch.

Important:
- `target branch` is where the new branch starts (defaults to repository default branch).
- `source base branch` is the original PR base branch used to compute the exact PR diff.

## Inputs Required
- `repo` in `owner/name` format
- source PR number
- SSH host alias for git remote (default `github.com`, custom example `mds`)
- API token env var for PR creation (default `GITHUB_PERSONAL_ACCESS_TOKEN`)

## Execution
Run:

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <target-branch> \
  --ssh-host <host-alias> \
  --create-pr
```

Override base branch only when needed:

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <target-branch> \
  --source-base-branch <original-pr-base-branch> \
  --ssh-host <host-alias>
```

## What It Does
1. Clones repository to `/tmp`
2. Fetches `target branch` and `pull/<PR>/head`
3. If PR head is a single commit, replays that exact commit onto target branch via `git cherry-pick -x` (drift-safe default)
4. Otherwise, detects/fetches source PR base branch from PR metadata (or `--source-base-branch`)
5. Computes PR-exact file diff from `merge-base(source base branch, PR head) -> PR head`
6. Applies the PR patch hunks onto the new branch with `git apply --3way --index`
7. Commits and pushes branch
8. Optionally creates PR via GitHub REST API

## Safety Notes
- Remote-only workflow; does not touch local working repo.
- If API access is missing, it still pushes the branch and prints a ready PR URL.
- By default, the script auto-detects the repository default branch for `target branch` when `--target-branch` is omitted.
- For single-commit PR heads, the script uses commit replay and does not require PR base branch metadata.
- For multi-commit PR heads, the script auto-detects the original PR base branch (for example `staging`) to avoid pulling unrelated drift.
