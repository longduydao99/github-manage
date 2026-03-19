#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: generate_commit_messages.sh --repo-path <path>
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

repo_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-path)
      [[ $# -ge 2 ]] || die "--repo-path requires a value"
      repo_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$repo_path" ]] || die "--repo-path is required"
[[ -d "$repo_path" ]] || die "repository path does not exist: $repo_path"
git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $repo_path"

load_env_file() {
  local env_file="$1"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
    return 0
  fi
  return 1
}

load_env_file "$repo_path/.env" || load_env_file "$(pwd)/.env" || true

llm_provider="${LLM_PROVIDER:-${LLM_PROVIDE:-}}"
llm_model="${LLM_MODEL:-}"

[[ -n "$llm_provider" ]] || die "LLM_PROVIDER is not set"
[[ -n "$llm_model" ]] || die "LLM_MODEL is not set"

diff_context="working tree changes"
tracked_diff=""
name_status=""
stat_summary=""

if ! git -C "$repo_path" diff --cached --quiet; then
  diff_context="staged changes"
  tracked_diff="$(git -C "$repo_path" diff --cached --no-ext-diff --binary -- .)"
  name_status="$(git -C "$repo_path" diff --cached --name-status -- .)"
  stat_summary="$(git -C "$repo_path" diff --cached --stat -- .)"
else
  tracked_diff="$(git -C "$repo_path" diff HEAD --no-ext-diff --binary -- .)"
  name_status="$(git -C "$repo_path" diff HEAD --name-status -- .)"
  stat_summary="$(git -C "$repo_path" diff HEAD --stat -- .)"
fi

untracked_files=""
if [[ "$diff_context" == "working tree changes" ]]; then
  untracked_files="$(git -C "$repo_path" ls-files --others --exclude-standard)"
fi

if [[ -z "$tracked_diff" && -z "$untracked_files" ]]; then
  die "no local changes found in $repo_path"
fi

untracked_section="None"
if [[ -n "$untracked_files" ]]; then
  untracked_section=""
  while IFS= read -r rel_path; do
    [[ -n "$rel_path" ]] || continue
    untracked_section+=$'FILE: '"$rel_path"$'\n'
    if [[ -f "$repo_path/$rel_path" ]]; then
      content_preview="$(sed -n '1,120p' "$repo_path/$rel_path" 2>/dev/null || true)"
      if [[ -n "$content_preview" ]]; then
        untracked_section+="$content_preview"$'\n'
      fi
    fi
    untracked_section+=$'\n'
  done <<< "$untracked_files"
fi

prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"' EXIT

cat > "$prompt_file" <<EOF
You are generating commit messages from a local git diff.

Return 2 to 4 options only.
Rules:
- Each option must be one line.
- Use Conventional Commit format.
- Keep each line concise and imperative.
- Do not use bullet markers or numbering.
- Do not explain your reasoning.
- Base every option strictly on the changes shown.

Repository path: $repo_path
Change set selected: $diff_context

Changed files:
$name_status

Diff stat:
$stat_summary

Tracked diff:
$tracked_diff

Untracked files:
$untracked_section
EOF

case "$llm_provider" in
  ollama)
    command -v ollama >/dev/null 2>&1 || die "ollama is not installed or not in PATH"
    ollama run "$llm_model" < "$prompt_file"
    ;;
  *)
    die "unsupported LLM_PROVIDER: $llm_provider"
    ;;
esac
