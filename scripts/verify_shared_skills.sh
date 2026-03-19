#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/skills/manifest.json"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if [[ ! -f "$MANIFEST_PATH" ]]; then
  printf 'FAIL: missing manifest at %s\n' "$MANIFEST_PATH" >&2
  exit 1
fi

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

if grep -R -nE '\.(codex|claude)/skills/' "$ROOT_DIR"/skills/*/SKILL.md "$ROOT_DIR"/skills/*/scripts/* 2>/dev/null; then
  fail "shared skill content still references agent-specific skill paths"
fi

for script_path in "$ROOT_DIR"/skills/*/scripts/*; do
  [[ -e "$script_path" ]] || continue
  [[ -x "$script_path" ]] || fail "script is not executable: $script_path"
done

for skill_name in $(shared_skill_names); do
  grep -Fq "skills/$skill_name/" "$ROOT_DIR/SKILLS_GUIDE.md" || fail "SKILLS_GUIDE missing canonical path for $skill_name"
done

bash -n "$ROOT_DIR/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh"
bash -n "$ROOT_DIR/skills/pr-copy-to-main-autonomous/scripts/test_gh_auth.sh"
[[ -e "$ROOT_DIR/.codex/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh" ]] || fail "Codex alias does not resolve"
[[ -e "$ROOT_DIR/.claude/skills/pr-copy-to-main-autonomous/scripts/copy_pr_to_main.sh" ]] || fail "Claude alias does not resolve"
