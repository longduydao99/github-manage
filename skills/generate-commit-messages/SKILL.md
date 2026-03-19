---
name: generate-commit-messages
description: Read file changes from a local Git repository path and generate 2-4 Conventional Commit message options using the configured LLM from .env. Use when the user asks to suggest commit messages from local changes, diffs, or staged files.
metadata:
  version: "1.0.0"
---

# Generate Commit Messages

Use this skill when the user wants commit message suggestions for a local repository on disk.

## Required Input

- `repo path` - local filesystem path to a Git repository

## Configuration

Read the LLM settings from `.env` using this precedence:

1. `.env` inside the target repository
2. `.env` in the current workspace root

Supported variables:
- `LLM_PROVIDER` - canonical provider name
- `LLM_PROVIDE` - legacy fallback spelling
- `LLM_MODEL` - model identifier passed to the provider

Current provider support:
- `ollama`

## Execution

Run:

```bash
bash .codex/skills/generate-commit-messages/scripts/generate_commit_messages.sh \
  --repo-path /absolute/path/to/repository
```

## Behavior

The script will:

1. Validate that the path is a Git repository
2. Prefer staged changes if any exist
3. Fall back to working tree changes when nothing is staged
4. Include tracked diffs, changed file summaries, and untracked files in the prompt
5. Ask the configured LLM for 2-4 Conventional Commit message options

## Output Rules

- Return strongest option first
- Use Conventional Commit prefixes such as `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- Keep each message to a single concise subject line
- Do not invent behavior not supported by the diff
- If the diff mixes unrelated work, prefer broader but still accurate subjects
