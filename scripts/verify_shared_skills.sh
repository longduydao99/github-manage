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
