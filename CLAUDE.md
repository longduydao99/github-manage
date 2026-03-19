# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A documentation and script-based Git management system that uses the gh CLI for authentication and a skill-based workflow. There is no application code to build or test — the primary artifacts are shell scripts and Markdown skill definitions.

## Environment Setup

Copy `.env.example` to `.env` and optionally fill in script defaults:

```
# GITHUB_ORG=your-org-or-username
# GITHUB_REPO=your-repo-name
```

Scripts use `gh auth login` for all git and API operations — no SSH key config or PAT env vars needed.

`.env` and `certs/` are gitignored. Never commit them.

## Skill System

Canonical skills live under `skills/`. Each skill folder contains:
- `SKILL.md` — front-matter + instructions (name, description, usage)
- `scripts/` — executable shell scripts that implement the skill

Claude-compatible discovery paths live under `.claude/skills/` as symlinks to canonical shared skills. `.codex/skills/` is also a symlinked compatibility layer for Codex-oriented tooling.

**Maintenance rule:** Any time a skill is created, updated, renamed, or removed, `SKILLS_GUIDE.md` must be updated in the same change.

## Available Skill: `pr-copy-to-main-autonomous`

Copies exact file changes from a source PR onto a new timestamped branch from a target branch, then optionally creates a new PR.

**Main script:**
```bash
bash skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <branch> \
  --create-pr
```

**Auth preflight check** (run before main script to verify credentials):
```bash
bash skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> --pr <number>
```

Key behaviour:
- Single-commit PR heads → `git cherry-pick -x` (drift-safe)
- Multi-commit PR heads → auto-detects source base branch from PR metadata, applies patch via `git apply --3way --index`
- Clones into `/tmp`; does not touch the local working repo
- If `--target-branch` is omitted, auto-detects the repository default branch

## Architecture

```
skills/<skill-name>/
    SKILL.md          # Skill definition (front-matter + instructions)
    scripts/          # Implementation scripts
skills/manifest.json  # Shared skill visibility source of truth
.codex/skills/<skill-name>/   # Symlink compatibility entrypoint
.claude/skills/<skill-name>/  # Symlink compatibility entrypoint
SKILLS_GUIDE.md       # Index of all available skills (keep in sync)
AGENTS.md             # Guidelines for AI agents working in this repo
README.md             # Full product documentation
.env / .env.example   # Optional script defaults (env only; never commit .env)
certs/                # Local SSH key material (gitignored)
```

## Key Conventions

- Skills are maintained canonically in `skills/`
- `.claude/skills/` and `.codex/skills/` are discovery aliases for shared skills
- GitHub authentication uses `gh auth login`; no SSH config or PAT env vars needed for scripts
