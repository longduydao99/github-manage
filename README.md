# Git Management System

A script-based Git management tool that uses the `gh` CLI for authentication and a skill-based workflow to streamline GitHub operations.

## Features

### 🔐 Authentication
- Uses `gh` CLI (`gh auth login`) — no SSH key config or PAT env vars needed
- Secure: credentials managed by `gh`, never hardcoded in scripts

### 🎯 Skill-Based Workflow
- Pre-defined skills in `skills/` handle common Git workflows
- Each skill is a `SKILL.md` definition + shell scripts
- Skills invoke `gh` and `git` directly — no external MCP dependencies

## Getting Started

### Prerequisites

- Git installed
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated via `gh auth login`

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd github-manager
```

2. Authenticate with GitHub:
```bash
gh auth login
```

3. (Optional) Copy `.env.example` to `.env` and set script defaults:
```bash
cp .env.example .env
```
```env
GITHUB_ORG=your-org-or-username
GITHUB_REPO=your-repo-name
```
These let you omit `--repo` on every CLI call. Scripts combine them as `${GITHUB_ORG}/${GITHUB_REPO}`.

## Usage

### Available Skills

Skills live under `skills/`. See `SKILLS_GUIDE.md` for the full index. Agent-specific directories under `.codex/skills/` and `.claude/skills/` are symlinked compatibility entrypoints.

#### `pr-copy-to-main-autonomous`

Copies exact file changes from an existing PR onto a new timestamped branch from a target branch, then optionally opens a new PR.

**Auth preflight check:**
```bash
bash skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh \
  --repo <owner/repo> --pr <number>
```

**Run:**
```bash
bash skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh \
  --repo <owner/repo> \
  --pr <number> \
  --target-branch <branch> \
  --create-pr
```

Key behaviour:
- Single-commit PR → `git cherry-pick -x`
- Multi-commit PR → `git apply --3way --index` against auto-detected source base
- Clones into `/tmp`; never touches your local working repo
- `--target-branch` is optional; defaults to the repo's default branch

## Architecture

```
skills/<skill-name>/
    SKILL.md          # Skill definition (name, description, usage)
    scripts/          # Shell scripts that implement the skill
.codex/skills/<skill-name>/   # Symlink compatibility entrypoint
.claude/skills/<skill-name>/  # Symlink compatibility entrypoint
skills/manifest.json          # Shared skill visibility source of truth
SKILLS_GUIDE.md       # Index of all skills (keep in sync with skills/)
AGENTS.md             # Guidelines for AI agents working in this repo
README.md             # This file
.env / .env.example   # Optional script defaults (gitignored; never commit .env)
```

## Security

- `.env` is gitignored — never commit it
- All GitHub API calls go through `gh` CLI, which manages token storage securely
- Scripts do not accept or store credentials directly

## Troubleshooting

### `gh` auth issues
```bash
gh auth status          # Check current auth state
gh auth login           # Re-authenticate if needed
```

### Skill not working
1. Verify `gh auth status` shows the correct account and scopes
2. Run the `test_gh_auth.sh` preflight for the skill
3. Check the script output for specific error messages

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add or update the canonical skill under `skills/`
4. Update `SKILLS_GUIDE.md` in the same change
5. Submit a pull request

## License

[Your License Here]
