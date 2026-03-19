---
name: pr-copy-to-main-autonomous
description: Copy exact file changes from an existing GitHub PR onto a new timestamped branch from a target branch, push the branch, and optionally create a new PR. Use when the user asks to copy, port, replicate, or apply PR changes onto another branch.
metadata:
  version: "1.1.0"
---

# PR Copy To Target Branch — Autonomous

Use this skill when the user asks to:
- Copy changes from an existing PR onto a different branch
- Port or replicate a PR to another branch (e.g. `main`, `staging`)
- Apply a PR's file changes to a new timestamped branch and push it
- Optionally create a new PR targeting a specific branch

## Required Inputs

Resolve `repo` using this precedence — do **not** ask the user unless both sources are absent:

1. **User's message** — if an org name, repo name, or `owner/repo` slug is mentioned, use it and pass `--repo owner/repo`
2. **`.env` at repo root** — if absent from the message, the scripts auto-read `GITHUB_ORG` + `GITHUB_REPO`. In this case, omit `--repo` from the command entirely.
3. **Ask the user** — only when neither the message nor `.env` provides the info.

| Input | Flag | Default |
|---|---|---|
| Repository | `--repo` | auto-read from `.env` (`GITHUB_ORG`+`GITHUB_REPO`) if not in message |
| Source PR number | `--pr` | *(required — from user or message)* |
| Target branch | `--target-branch` | auto-detected from repo default |
| Create PR after push | `--create-pr` | off (flag, no value) |
| Override source base branch | `--source-base-branch` | auto-detected from PR metadata |

Prerequisite: gh CLI must be authenticated (`gh auth login`). No SSH config or PAT env vars needed for scripts.

## Execution Steps

### Step 1 — Auth preflight (optional, run when user wants to verify credentials)

Repo from user's message:
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> --pr <number>
```

Repo from `.env` (omit `--repo`):
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --pr <number>
```

With PR create permission probe (safe, no PR created):
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> \
  --check-create-pr
```

### Step 2 — Run the main script

Repo from user's message:
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> --pr <number> --target-branch <branch> --create-pr
```

Repo from `.env` (omit `--repo`):
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --pr <number> --target-branch <branch> --create-pr
```

Override source base branch only when PR metadata cannot be auto-detected:
```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <branch> \
  --source-base-branch <original-pr-base>
```

## What the Script Does

1. Clones repository to `/tmp` (never touches your local working repo)
2. Fetches `target-branch` and `pull/<PR>/head`
3. **Single-commit PR head** → replays via `git cherry-pick -x` (drift-safe)
4. **Multi-commit PR head** → auto-detects PR's original base branch from metadata, computes exact PR diff (`merge-base → PR head`), applies patch with `git apply --3way --index`
5. Commits and pushes the new timestamped branch
6. If `--create-pr` is set, creates a PR via `gh pr create`; otherwise prints a ready PR URL

## Key Terminology

- **target branch** — where the new branch starts (e.g. `main`). Defaults to the repo's default branch.
- **source base branch** — the original PR base used to isolate its exact diff (e.g. `staging`). Auto-detected from PR metadata; only override when that fails.

## Safety Notes

- Remote-only: clones to `/tmp`, leaves local repo untouched.
- If gh PR creation fails, the script still pushes the branch and prints a ready-to-use PR URL.
- On failure, the script prints a clear reason and exits non-zero.
