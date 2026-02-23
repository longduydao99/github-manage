# Repository Guidelines

## Project Structure & Module Organization
This repository is currently minimal and documentation-centric.
- `README.md` contains the primary product description and usage guidance.
- `certs/` stores local certificate/key material such as `certs/id`.
If source code, tests, or assets are added later, place them under clear top-level directories (for example `src/`, `tests/`, `assets/`) and document them here.

## Build, Test, and Development Commands
No build or test commands are defined in this repository today.
- If you add automation, document the exact commands and purpose, for example:
  - `make build` to compile artifacts
  - `npm test` or `uv run pytest` to execute tests

## Coding Style & Naming Conventions
No code style rules are defined yet. If you add code:
- Prefer 2- or 4-space indentation consistently per language.
- Use descriptive, lowercase directory names (for example `skills/`, `scripts/`).
- Add format/lint commands to this document once they exist.

## Testing Guidelines
There are no test frameworks configured.
- If tests are introduced, document the framework, test file naming pattern, and the command to run them (for example `tests/test_*.py` via `uv run pytest`).

## Commit & Pull Request Guidelines
This directory is not a Git repository, so no commit history is available.
- If you initialize Git, adopt clear, imperative commit messages (for example `Add skill loader docs`).
- Pull requests should include a brief summary, motivation, and any configuration or security considerations (especially for credentials or keys).

## Security & Configuration Tips
- Do not commit private keys or secrets. The `certs/` directory should only contain non-sensitive placeholders unless explicitly required.
- If you add a `.env`, keep it out of version control and document required variables in `README.md`.

## Agent-Specific Instructions
If you add automation or agent workflows, document:
- Where skills/configuration live (for example `skills/`).
- How to reload or apply changes (for example a `reload-skills` command).
- Keep `SKILLS_GUIDE.md` in sync with local skills.

### Skills Documentation Policy
- When creating, updating, renaming, or removing any skill under `.codex/skills/`, you must also update `SKILLS_GUIDE.md` in the same change.
- `SKILLS_GUIDE.md` should include:
  - Skill name
  - Skill path
  - Purpose
  - Basic usage command
