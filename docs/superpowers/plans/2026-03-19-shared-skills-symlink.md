# Shared Skills Symlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate this repository to a canonical `skills/` tree with shared-skill symlink entrypoints for Codex and Claude, plus manifest-driven verification and updated documentation.

**Architecture:** Create a neutral `skills/` source-of-truth tree, move shared skill directories into it, and expose them through `.codex/skills/` and `.claude/skills/` symlinks. Add a small verification script that reads a visibility manifest, validates shared-skill exposure and symlink health, and keep existing shell-based tests working against canonical paths.

**Tech Stack:** Bash, POSIX shell utilities, Git symlinks, Markdown, JSON

---

## File Structure

### New files

- `skills/manifest.json`
  Records canonical skill names and whether each skill is `shared` or `agent-specific`.
- `skills/generate-commit-messages/SKILL.md`
  Canonical skill definition migrated from `.codex/skills/generate-commit-messages/SKILL.md` only if Phase 1 classifies this skill as `shared`.
- `skills/generate-commit-messages/scripts/generate_commit_messages.sh`
  Canonical script migrated from `.codex` only if Phase 1 classifies this skill as `shared`.
- `skills/pr-copy-to-main-autonomous/SKILL.md`
  Canonical shared skill definition reconciled from `.codex` and `.claude`.
- `skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh`
  Canonical shared script migrated from `.codex`.
- `skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh`
  Canonical shared script migrated from `.codex`.
- `scripts/verify_shared_skills.sh`
  Repository verification entrypoint for manifest, symlink, path, mode-bit, and docs checks.

### Modified files

- `.codex/skills/generate-commit-messages`
  Replace real directory with symlink to `../../skills/generate-commit-messages` only if Phase 1 classifies this skill as `shared`.
- `.codex/skills/pr-copy-to-main-autonomous`
  Replace real directory with symlink to `../../skills/pr-copy-to-main-autonomous`.
- `.claude/skills/pr-copy-to-main-autonomous`
  Replace real directory with symlink to `../../skills/pr-copy-to-main-autonomous`.
- `.claude/skills/generate-commit-messages`
  Create only if Phase 1 classifies `generate-commit-messages` as `shared`.
- `tests/generate_commit_messages_test.sh`
  Resolve the canonical skill script path only if `generate-commit-messages` is migrated into the shared canonical tree.
- `README.md`
  Document `skills/` as canonical and agent trees as compatibility symlinks.
- `SKILLS_GUIDE.md`
  Update skill paths, usage commands, and maintenance rules to match the canonical tree and manifest-driven ownership.
- `CLAUDE.md`
  Update repository skill architecture description to use canonical `skills/`.
- `AGENTS.md`
  Update the skills documentation policy so it refers to canonical `skills/` rather than only `.codex/skills/`.

## Task 1: Inventory Existing Skills And Record Visibility

**Files:**
- Create: `skills/manifest.json`
- Test: `skills/manifest.json`

- [ ] **Step 1: Enumerate the current skill inventory**

Run:

```bash
find .codex/skills -mindepth 1 -maxdepth 1 -type d -print | sort
find .claude/skills -mindepth 1 -maxdepth 1 -type d -print | sort
```

Expected: a complete list of current real skill directories for both agent trees

- [ ] **Step 2: Compare duplicate skill definitions before classifying them**

For each skill name that appears in both trees, run:

```bash
diff -u .codex/skills/<skill-name>/SKILL.md .claude/skills/<skill-name>/SKILL.md
```

Expected: no output for byte-identical duplicates; if there is output, stop and reconcile before proceeding

- [ ] **Step 3: Write the manifest from the observed inventory**

Create `skills/manifest.json` from the actual inventory, not from assumptions. The initial shape should be:

```json
{
  "skills": [
    {
      "name": "<shared-skill>",
      "visibility": "shared",
      "agents": ["codex", "claude"]
    },
    {
      "name": "<one-sided-skill>",
      "visibility": "agent-specific",
      "agents": ["codex"]
    }
  ]
}
```

Rules:

- only mark a one-sided skill as `shared` after explicitly deciding to expose it to the missing agent
- if there is no explicit decision yet, record it as `agent-specific` for the currently known agent
- keep names lowercase kebab-case to match the spec

- [ ] **Step 4: Validate the manifest contents directly**

Run: `cat skills/manifest.json`
Expected: every discovered skill appears exactly once with explicit `visibility` and `agents`

- [ ] **Step 5: Commit the inventory manifest**

```bash
git add skills/manifest.json
git commit -m "chore: record shared skill visibility manifest"
```

## Task 2: Add Verification Harness Around The Manifest

**Files:**
- Create: `scripts/verify_shared_skills.sh`
- Modify: `skills/manifest.json`
- Test: `scripts/verify_shared_skills.sh`

- [ ] **Step 1: Write the failing verification harness first**

Create `scripts/verify_shared_skills.sh` with a minimal failing check that expects:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/skills/manifest.json"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  printf 'FAIL: missing manifest at %s\n' "$MANIFEST_PATH" >&2
  exit 1
fi
```

- [ ] **Step 2: Run verification to confirm it reads the manifest baseline**

Run: `bash scripts/verify_shared_skills.sh`
Expected: exits 0 or reaches the next missing-check once the manifest exists

- [ ] **Step 3: Expand verification with concrete shared-skill checks**

Extend `scripts/verify_shared_skills.sh` so it:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/skills/manifest.json"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

shared_skill_names() {
  jq -r '.skills[] | select(.visibility == "shared") | .name' "$MANIFEST_PATH"
}

for skill_name in $(shared_skill_names); do
  [[ -f "$ROOT_DIR/skills/$skill_name/SKILL.md" ]] || fail "missing canonical SKILL.md for $skill_name"
  [[ -L "$ROOT_DIR/.codex/skills/$skill_name" ]] || fail "missing Codex symlink for $skill_name"
  [[ -L "$ROOT_DIR/.claude/skills/$skill_name" ]] || fail "missing Claude symlink for $skill_name"
  [[ -e "$ROOT_DIR/.codex/skills/$skill_name/SKILL.md" ]] || fail "broken Codex symlink target for $skill_name"
  [[ -e "$ROOT_DIR/.claude/skills/$skill_name/SKILL.md" ]] || fail "broken Claude symlink target for $skill_name"
done
```

If `jq` is unavailable in the repo environment, replace it with an inline `python3 -c` JSON reader and document that decision in the script header.

- [ ] **Step 4: Run verification again**

Run: `bash scripts/verify_shared_skills.sh`
Expected: FAIL because canonical `skills/` directories and symlinks do not exist yet

- [ ] **Step 5: Leave the harness uncommitted until migration makes it pass**

Do not commit a knowingly failing verification checkpoint. The first commit that includes `scripts/verify_shared_skills.sh` should come after Task 3 verification passes.

## Task 3: Migrate Shared Skill Directories Into Canonical `skills/`

**Files:**
- Create: `skills/generate-commit-messages/SKILL.md`
- Create: `skills/generate-commit-messages/scripts/generate_commit_messages.sh`
- Create: `skills/pr-copy-to-main-autonomous/SKILL.md`
- Create: `skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh`
- Create: `skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh`
- Modify: `.codex/skills/generate-commit-messages`
- Modify: `.codex/skills/pr-copy-to-main-autonomous`
- Modify: `.claude/skills/pr-copy-to-main-autonomous`
- Modify: `.claude/skills/generate-commit-messages`
- Test: `scripts/verify_shared_skills.sh`

- [ ] **Step 1: Create the canonical directories**

Run:

```bash
mkdir -p skills/generate-commit-messages/scripts
mkdir -p skills/pr-copy-to-main-autonomous/scripts
```

Expected: `skills/` tree exists with empty skill directories

- [ ] **Step 2: Copy only manifest-declared shared skills into canonical paths**

Move or copy the current shared files into `skills/` so the canonical copies contain the reconciled shared content before path cleanup:

```bash
cp .codex/skills/generate-commit-messages/SKILL.md skills/generate-commit-messages/SKILL.md
cp .codex/skills/generate-commit-messages/scripts/generate_commit_messages.sh skills/generate-commit-messages/scripts/generate_commit_messages.sh
cp <reconciled-pr-copy-skill-md> skills/pr-copy-to-main-autonomous/SKILL.md
cp .codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh
cp .codex/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh
chmod +x skills/generate-commit-messages/scripts/generate_commit_messages.sh
chmod +x skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh
chmod +x skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh
```

For `pr-copy-to-main-autonomous`, `<reconciled-pr-copy-skill-md>` means:

- `.codex/skills/pr-copy-to-main-autonomous/SKILL.md` if the duplicate files were confirmed identical in Task 1
- a temporary reconciled file produced from manual conflict resolution if the duplicates differed

Do not assume `.codex` wins if the duplicated `SKILL.md` files are not byte-identical.

If `generate-commit-messages` remains `agent-specific` in the manifest, do not copy it into `skills/`, do not replace `.codex/skills/generate-commit-messages` with a shared-skill symlink, do not expose it to Claude, and skip Task 5 entirely.

- [ ] **Step 3: Replace agent-specific directories with symlinks for shared skills only**

Run:

```bash
rm -rf .codex/skills/generate-commit-messages
ln -s ../../skills/generate-commit-messages .codex/skills/generate-commit-messages
rm -rf .codex/skills/pr-copy-to-main-autonomous
ln -s ../../skills/pr-copy-to-main-autonomous .codex/skills/pr-copy-to-main-autonomous
rm -rf .claude/skills/pr-copy-to-main-autonomous
ln -s ../../skills/pr-copy-to-main-autonomous .claude/skills/pr-copy-to-main-autonomous
```

Only if the manifest classifies `generate-commit-messages` as `shared`, also run:

```bash
ln -s ../../skills/generate-commit-messages .claude/skills/generate-commit-messages
```

Expected:

```bash
test -L .codex/skills/generate-commit-messages
test -L .codex/skills/pr-copy-to-main-autonomous
test -L .claude/skills/pr-copy-to-main-autonomous
```

- [ ] **Step 4: Run verification to confirm the canonical tree and symlinks resolve**

Run: `bash scripts/verify_shared_skills.sh`
Expected: PASS for manifest, canonical `SKILL.md`, symlink existence, and symlink target resolution checks

- [ ] **Step 5: Commit the filesystem migration only after verification passes**

```bash
git add skills .codex/skills .claude/skills
git commit -m "refactor: move shared skills to canonical tree"
```

## Task 4: Make Skill References Canonical And Symlink-Safe

**Files:**
- Modify: `skills/generate-commit-messages/SKILL.md`
- Modify: `skills/pr-copy-to-main-autonomous/SKILL.md`
- Modify: `skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh`
- Modify: `skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh`
- Test: `scripts/verify_shared_skills.sh`

- [ ] **Step 1: Write the failing path assertions into the verification script**

Extend `scripts/verify_shared_skills.sh` with checks that fail when shared `SKILL.md` files still hardcode agent-specific skill paths:

```bash
if grep -R -nE '\.(codex|claude)/skills/' "$ROOT_DIR"/skills/*/SKILL.md "$ROOT_DIR"/skills/*/scripts/* 2>/dev/null; then
  fail "shared skill content still references agent-specific skill paths"
fi
```

Adjust the file globbing to avoid false failures when optional directories are absent.

- [ ] **Step 2: Run verification to confirm the path check fails**

Run: `bash scripts/verify_shared_skills.sh`
Expected: FAIL because current shared content still references `.codex/skills/...` or `.claude/skills/...`

- [ ] **Step 3: Update shared skill content to canonical paths**

Rewrite command examples in both shared `SKILL.md` files from:

```bash
bash .codex/skills/<skill-name>/scripts/<script>.sh
```

to:

```bash
bash skills/<skill-name>/scripts/<script>.sh
```

Also inspect `skills/pr-copy-to-main-autonomous/scripts/*.sh` for caller-path assumptions. If a script anchors itself with `dirname "$0"`, normalize it to a real-path-based pattern such as:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
```

Only make these script changes if the audit finds a real symlink-resolution risk.

- [ ] **Step 4: Run verification after canonical path cleanup**

Run: `bash scripts/verify_shared_skills.sh`
Expected: PASS for path-reference checks

- [ ] **Step 5: Commit the canonical path updates**

```bash
git add skills/generate-commit-messages/SKILL.md skills/pr-copy-to-main-autonomous/SKILL.md skills/pr-copy-to-main-autonomous/scripts
git commit -m "refactor: normalize shared skill paths"
```

## Task 5: Update Tests To Follow Canonical Skill Paths

**Files:**
- Modify: `tests/generate_commit_messages_test.sh`
- Test: `tests/generate_commit_messages_test.sh`

This task applies only if `generate-commit-messages` is classified as `shared` and migrated into `skills/`.

- [ ] **Step 1: Write the failing test expectation**

Change the script-under-test path in `tests/generate_commit_messages_test.sh` from:

```bash
SCRIPT_PATH="$ROOT_DIR/.codex/skills/generate-commit-messages/scripts/generate_commit_messages.sh"
```

to a canonical-path assertion pattern:

```bash
SCRIPT_PATH="$ROOT_DIR/skills/generate-commit-messages/scripts/generate_commit_messages.sh"
[[ -x "$SCRIPT_PATH" ]] || fail "missing canonical script path"
```

- [ ] **Step 2: Run the test to verify current migration status**

Run: `bash tests/generate_commit_messages_test.sh`
Expected: PASS if the canonical script already exists and remains executable, otherwise FAIL at the new assertion

- [ ] **Step 3: Make the minimal test-only adjustments**

If the test fails because executable bits or path setup are wrong, fix only the missing prerequisite in the migrated files. Do not broaden the test scope.

- [ ] **Step 4: Run the test again**

Run: `bash tests/generate_commit_messages_test.sh`
Expected: `All tests passed.`

- [ ] **Step 5: Commit the test path update**

```bash
git add tests/generate_commit_messages_test.sh
git commit -m "test: use canonical shared skill paths"
```

## Task 6: Strengthen Verification For Docs Coverage, Target Resolution, And Smoke Checks

**Files:**
- Modify: `scripts/verify_shared_skills.sh`
- Test: `scripts/verify_shared_skills.sh`

- [ ] **Step 1: Add one failing mode-bit or docs check**

Extend `scripts/verify_shared_skills.sh` with explicit checks such as:

```bash
for script_path in "$ROOT_DIR"/skills/*/scripts/*; do
  [[ -x "$script_path" ]] || fail "script is not executable: $script_path"
done
```

and a focused docs coverage assertion such as:

```bash
grep -Fq 'skills/generate-commit-messages/' "$ROOT_DIR/SKILLS_GUIDE.md" || fail "SKILLS_GUIDE missing canonical generate-commit-messages path"
grep -Fq 'skills/pr-copy-to-main-autonomous/' "$ROOT_DIR/SKILLS_GUIDE.md" || fail "SKILLS_GUIDE missing canonical pr-copy-to-main-autonomous path"
```

- [ ] **Step 2: Run verification to confirm docs checks fail before docs are updated**

Run: `bash scripts/verify_shared_skills.sh`
Expected: FAIL on `SKILLS_GUIDE` canonical path coverage

- [ ] **Step 3: Keep the checks focused on manifest-declared shared skills and add smoke checks**

Refactor the hardcoded docs assertions into a loop over the manifest’s shared skills so renamed skills stay covered automatically.

Also add smoke checks for `pr-copy-to-main-autonomous`:

```bash
bash -n "$ROOT_DIR/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh"
bash -n "$ROOT_DIR/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh"
[[ -e "$ROOT_DIR/.codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh" ]] || fail "Codex alias does not resolve"
[[ -e "$ROOT_DIR/.claude/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh" ]] || fail "Claude alias does not resolve"
```

- [ ] **Step 4: Re-run verification**

Run: `bash scripts/verify_shared_skills.sh`
Expected: still FAIL until the docs are updated in the next task

## Task 7: Update Repository Documentation To The Canonical Skill Model

**Files:**
- Modify: `README.md`
- Modify: `SKILLS_GUIDE.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Test: `scripts/verify_shared_skills.sh`

- [ ] **Step 1: Update `README.md` architecture and usage examples**

Rewrite the skill architecture section so it documents:

```text
skills/<skill-name>/       # canonical source of truth
.codex/skills/<skill-name> # symlink compatibility entrypoint
.claude/skills/<skill-name># symlink compatibility entrypoint
skills/manifest.json       # visibility source of truth
```

Replace any `.codex/skills/...` command examples with canonical `skills/...` examples.

- [ ] **Step 2: Update `SKILLS_GUIDE.md` to match the new ownership model**

Make these changes:

- `skills/` is canonical
- `.codex/skills/` and `.claude/skills/` are discovery aliases
- skill path entries point to `skills/<skill-name>/`
- usage commands use canonical paths
- maintenance rules require updating `SKILLS_GUIDE.md` when canonical `skills/` change

- [ ] **Step 3: Update `CLAUDE.md` and `AGENTS.md`**

Adjust both files so they no longer describe `.codex/skills/` as the primary skill home. `AGENTS.md` should explicitly say the documentation policy applies when changing `skills/`.

- [ ] **Step 4: Run verification and the existing shell test suite**

Run:

```bash
bash scripts/verify_shared_skills.sh
bash tests/generate_commit_messages_test.sh
```

Expected:

- verification script exits 0
- generate commit messages test prints `All tests passed.`

- [ ] **Step 5: Review the final Git diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only the planned migration, verification, test, and docs files are changed

- [ ] **Step 6: Commit the docs and final verification state**

```bash
git add README.md SKILLS_GUIDE.md CLAUDE.md AGENTS.md scripts/verify_shared_skills.sh
git commit -m "docs: document canonical shared skills layout"
```

## Task 8: Final Validation And Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-03-19-shared-skills-symlink.md`

- [ ] **Step 1: Run the final validation set**

Run:

```bash
bash scripts/verify_shared_skills.sh
bash tests/generate_commit_messages_test.sh
find .codex/skills -maxdepth 1 -type l -print | sort
find .claude/skills -maxdepth 1 -type l -print | sort
```

Expected:

- both verification commands exit 0
- shared skill names appear as symlinks in both agent trees

- [ ] **Step 2: Record any deviations immediately**

If any skill remains intentionally `agent-specific`, record that fact in `skills/manifest.json` and mention it in the execution summary. Do not silently force parity.

- [ ] **Step 3: Prepare the handoff summary**

Summarize:

- canonical tree created
- manifest added
- symlink exposure working for shared skills
- tests and verification commands passing
- any unsupported edge cases or follow-up work

- [ ] **Step 4: Commit any last manifest-only correction if needed**

```bash
git add skills/manifest.json
git commit -m "chore: finalize shared skill visibility metadata"
```

Only do this if the manifest changed after final validation.
