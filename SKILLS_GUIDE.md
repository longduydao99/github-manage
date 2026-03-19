# Skills Guide

This file explains how to use local skills in this repository.

## Where Skills Live

### Canonical Skills (`skills/`)
- Canonical skill folders are stored under `skills/`.
- Each skill must contain `SKILL.md`.
- Optional executable automation can live in `scripts/` inside the skill folder.
- `skills/manifest.json` is the visibility source of truth for shared skills.

### Agent Compatibility Paths
- `.codex/skills/` contains symlinks to canonical shared skills in `skills/`.
- `.claude/skills/` contains symlinks to canonical shared skills in `skills/`.
- These directories are discovery entrypoints only. Edit the canonical files in `skills/`, not the symlink aliases.

## How To Use a Skill

1. Identify the canonical skill folder under `skills/`.
2. Read the skill instruction file `skills/<skill-name>/SKILL.md`.
3. Run the commands described in that skill using canonical `skills/...` paths.

## Available Local Skills

### `generate-commit-messages`
- Canonical path: `skills/generate-commit-messages/`
- Codex path: `.codex/skills/generate-commit-messages/`
- Claude Code path: `.claude/skills/generate-commit-messages/`
- Purpose: Read local Git repository changes from a filesystem path and generate 2-4 Conventional Commit message options using the configured LLM from `.env`.

Run:

```bash
bash skills/generate-commit-messages/scripts/generate_commit_messages.sh \
  --repo-path /absolute/path/to/repository
```

Notes:
- Reads `LLM_PROVIDER` and `LLM_MODEL` from `.env` in the target repo first, then from the current workspace root.
- Supports legacy `LLM_PROVIDE` as a fallback for compatibility.
- Prefers staged changes; if nothing is staged, it falls back to working tree and untracked changes.

### `pr-copy-to-main-autonomous`
- Canonical path: `skills/pr-copy-to-main-autonomous/`
- Codex path: `.codex/skills/pr-copy-to-main-autonomous/`
- Claude Code path: `.claude/skills/pr-copy-to-main-autonomous/`
- Purpose: Create a new timestamped branch from a target branch, copy exact file changes from a source PR, push the branch, and optionally create a PR.

Requires `gh auth login` (run once). No SSH config or PAT env vars needed for scripts.

`--repo` is optional when `GITHUB_ORG` and `GITHUB_REPO` are set in `.env`. Pass `--repo` explicitly to override.

Run (with `--repo`):

```bash
bash skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <target-branch> \
  --create-pr
```

Run (repo from `.env`, omit `--repo`):

```bash
bash skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --pr <number> \
  --target-branch <target-branch> \
  --create-pr
```

Notes:
- `--target-branch` is where the new branch starts. If omitted, repository default branch is auto-detected.
- If the PR head is a single commit, the script replays that exact commit on top of target branch (`git cherry-pick -x`) to avoid branch-drift.
- For multi-commit PRs, the script auto-detects the PR's original base branch from metadata and applies the PR patch hunks onto target branch.
- If PR metadata or diff cannot be fetched for multi-commit PRs, the script exits with a failure reason.

Auth preflight (with `--repo`):

```bash
bash skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> \
  --pr <number>
```

Auth preflight (repo from `.env`):

```bash
bash skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --pr <number>
```

## Maintenance Rule
- Whenever any canonical skill is created, updated, renamed, or removed under `skills/`, update this `SKILLS_GUIDE.md` in the same change.
- Keep `skills/manifest.json` aligned with shared skill exposure under `.codex/skills/` and `.claude/skills/`.
