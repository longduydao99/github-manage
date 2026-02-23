# Skills Guide

This file explains how to use local skills in this repository.

## Where Skills Live
- Skill folders are stored under `.codex/skills/`.
- Each skill must contain `SKILL.md`.
- Optional executable automation can live in `scripts/` inside the skill folder.

## How To Use a Skill
1. Identify the skill folder under `.codex/skills/`.
2. Read the skill instruction file `<skill>/SKILL.md`.
3. Run the commands described in that skill.

## Available Local Skills

### `pr-copy-to-main-autonomous`
- Path: `.codex/skills/pr-copy-to-main-autonomous/`
- Purpose: Create a new timestamped branch from a target branch, copy exact file changes from a source PR, push the branch, and optionally create a PR via API.

Run:

```bash
bash .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <target-branch> \
  --ssh-host <ssh-host-alias> \
  --create-pr
```

Notes:
- `--target-branch` is where the new branch starts. If omitted, repository default branch is auto-detected.
- By default, the script auto-detects the PR's original base branch from PR metadata.
- You can still set `--source-base-branch` explicitly (for example `staging`) when needed.
- If PR head has no diff against that base (already merged), the script auto-falls back to the merged PR commit diff on the base branch.

## Maintenance Rule
- Whenever any skill is created, updated, renamed, or removed under `.codex/skills/`, update this `SKILLS_GUIDE.md` in the same change.
