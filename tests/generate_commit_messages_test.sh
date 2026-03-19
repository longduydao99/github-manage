#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/skills/generate-commit-messages/scripts/generate_commit_messages.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -x "$SCRIPT_PATH" ]] || fail "missing canonical script path"

assert_contains() {
  local needle="$1"
  local haystack_file="$2"
  if ! grep -Fq "$needle" "$haystack_file"; then
    printf 'Expected to find: %s\n' "$needle" >&2
    printf 'In file: %s\n' "$haystack_file" >&2
    printf 'Actual contents:\n' >&2
    cat "$haystack_file" >&2
    fail "missing expected content"
  fi
}

make_temp_repo() {
  local repo_dir
  repo_dir="$(mktemp -d)"
  git -C "$repo_dir" init >/dev/null
  git -C "$repo_dir" config user.name "Test User"
  git -C "$repo_dir" config user.email "test@example.com"
  printf 'base\n' > "$repo_dir/example.txt"
  git -C "$repo_dir" add example.txt
  git -C "$repo_dir" commit -m "chore: initial commit" >/dev/null
  printf '%s\n' "$repo_dir"
}

make_mock_ollama() {
  local bin_dir="$1"
  local output_file="$2"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/ollama" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${MOCK_OLLAMA_ARGS_FILE:?}"
cat > "${MOCK_OLLAMA_PROMPT_FILE:?}"
cat "${MOCK_OLLAMA_RESPONSE_FILE:?}"
EOF
  chmod +x "$bin_dir/ollama"
}

test_prefers_staged_changes() {
  local temp_dir repo_dir mock_bin prompt_file args_file response_file output_file
  temp_dir="$(mktemp -d)"
  repo_dir="$(make_temp_repo)"
  mock_bin="$temp_dir/bin"
  prompt_file="$temp_dir/prompt.txt"
  args_file="$temp_dir/args.txt"
  response_file="$temp_dir/response.txt"
  output_file="$temp_dir/output.txt"

  printf 'feat: add staged option\nfix: adjust staged path\n' > "$response_file"
  make_mock_ollama "$mock_bin" "$output_file"

  cat > "$repo_dir/.env" <<'EOF'
LLM_PROVIDER=ollama
LLM_MODEL=test-model
EOF

  printf 'staged change\n' >> "$repo_dir/example.txt"
  git -C "$repo_dir" add example.txt
  printf 'unstaged only\n' > "$repo_dir/unstaged.txt"

  PATH="$mock_bin:$PATH" \
  MOCK_OLLAMA_ARGS_FILE="$args_file" \
  MOCK_OLLAMA_PROMPT_FILE="$prompt_file" \
  MOCK_OLLAMA_RESPONSE_FILE="$response_file" \
  bash "$SCRIPT_PATH" --repo-path "$repo_dir" > "$output_file"

  assert_contains "run test-model" "$args_file"
  assert_contains "staged changes" "$prompt_file"
  assert_contains "staged change" "$prompt_file"
  if grep -Fq "unstaged only" "$prompt_file"; then
    fail "prompt included unstaged changes when staged changes were present"
  fi
  assert_contains "feat: add staged option" "$output_file"
}

test_falls_back_to_working_tree_changes() {
  local temp_dir repo_dir mock_bin prompt_file args_file response_file output_file
  temp_dir="$(mktemp -d)"
  repo_dir="$(make_temp_repo)"
  mock_bin="$temp_dir/bin"
  prompt_file="$temp_dir/prompt.txt"
  args_file="$temp_dir/args.txt"
  response_file="$temp_dir/response.txt"
  output_file="$temp_dir/output.txt"

  printf 'fix: capture working tree change\nchore: update local files\n' > "$response_file"
  make_mock_ollama "$mock_bin" "$output_file"

  cat > "$repo_dir/.env" <<'EOF'
LLM_PROVIDER=ollama
LLM_MODEL=test-model
EOF

  printf 'working tree change\n' >> "$repo_dir/example.txt"

  PATH="$mock_bin:$PATH" \
  MOCK_OLLAMA_ARGS_FILE="$args_file" \
  MOCK_OLLAMA_PROMPT_FILE="$prompt_file" \
  MOCK_OLLAMA_RESPONSE_FILE="$response_file" \
  bash "$SCRIPT_PATH" --repo-path "$repo_dir" > "$output_file"

  assert_contains "working tree changes" "$prompt_file"
  assert_contains "working tree change" "$prompt_file"
  assert_contains "fix: capture working tree change" "$output_file"
}

test_supports_legacy_llm_provide_name() {
  local temp_dir repo_dir mock_bin prompt_file args_file response_file output_file
  temp_dir="$(mktemp -d)"
  repo_dir="$(make_temp_repo)"
  mock_bin="$temp_dir/bin"
  prompt_file="$temp_dir/prompt.txt"
  args_file="$temp_dir/args.txt"
  response_file="$temp_dir/response.txt"
  output_file="$temp_dir/output.txt"

  printf 'docs: explain provider fallback\nchore: support env typo\n' > "$response_file"
  make_mock_ollama "$mock_bin" "$output_file"

  cat > "$repo_dir/.env" <<'EOF'
LLM_PROVIDE=ollama
LLM_MODEL=legacy-model
EOF

  printf 'legacy provider env\n' >> "$repo_dir/example.txt"

  PATH="$mock_bin:$PATH" \
  MOCK_OLLAMA_ARGS_FILE="$args_file" \
  MOCK_OLLAMA_PROMPT_FILE="$prompt_file" \
  MOCK_OLLAMA_RESPONSE_FILE="$response_file" \
  bash "$SCRIPT_PATH" --repo-path "$repo_dir" > "$output_file"

  assert_contains "run legacy-model" "$args_file"
  assert_contains "legacy provider env" "$prompt_file"
  assert_contains "docs: explain provider fallback" "$output_file"
}

test_prefers_staged_changes
test_falls_back_to_working_tree_changes
test_supports_legacy_llm_provide_name

printf 'All tests passed.\n'
