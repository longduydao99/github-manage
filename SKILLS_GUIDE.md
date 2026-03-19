# Skills Guide

This file explains how to use local skills in this repository.

## Where Skills Live

### Codex Skills (`.codex/skills/`)
- Skill folders are stored under `.codex/skills/`.
- Each skill must contain `SKILL.md`.
- Optional executable automation can live in `scripts/` inside the skill folder.

### Claude Code Skills (`.claude/skills/`)
- Project-level Claude Code skills live under `.claude/skills/`.
- Each skill must contain `SKILL.md` with YAML front-matter (`name`, `description`).
- Claude Code discovers and applies these skills automatically based on the `description` field.
- These skills reference scripts under `.codex/skills/<skill-name>/scripts/`.

## How To Use a Skill

### Codex Skills
1. Identify the skill folder under `.codex/skills/`.
2. Read the skill instruction file `<skill>/SKILL.md`.
3. Run the commands described in that skill.

### Claude Code Skills
Claude Code automatically detects and loads skills from `.claude/skills/` based on context. You can also explicitly invoke a skill by describing the task (e.g. "copy PR #123 to main"). Claude will match the description and follow the skill's instructions.

## Available Local Skills

### `generate-commit-messages`
- Codex path: `.codex/skills/generate-commit-messages/`
- Purpose: Read local Git repository changes from a filesystem path and generate 2-4 Conventional Commit message options using the configured LLM from `.env`.

Run:

```bash
bash .codex/skills/generate-commit-messages/scripts/generate_commit_messages.sh \
  --repo-path /absolute/path/to/repository
```

Notes:
- Reads `LLM_PROVIDER` and `LLM_MODEL` from `.env` in the target repo first, then from the current workspace root.
- Supports legacy `LLM_PROVIDE` as a fallback for compatibility.
- Prefers staged changes; if nothing is staged, it falls back to working tree and untracked changes.

### `pr-copy-to-main-autonomous`
- Codex path: `.codex/skills/pr-copy-to-main-autonomous/`
- Claude Code path: `.claude/skills/pr-copy-to-main-autonomous/`
- Purpose: Create a new timestamped branch from a target branch, copy exact file changes from a source PR, push the branch, and optionally create a PR.

Requires `gh auth login` (run once). No SSH config or PAT env vars needed for scripts.

`--repo` is optional when `GITHUB_ORG` and `GITHUB_REPO` are set in `.env`. Pass `--repo` explicitly to override.

Run (with `--repo`):

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <target-branch> \
  --create-pr
```

Run (repo from `.env`, omit `--repo`):

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
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
bash .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> \
  --pr <number>
```

Auth preflight (repo from `.env`):

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --pr <number>
```

## Maintenance Rule
- Whenever any skill is created, updated, renamed, or removed under `.codex/skills/`, update this `SKILLS_GUIDE.md` in the same change.
