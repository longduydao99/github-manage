#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  copy_pr_to_main.sh --repo owner/repo --pr 1686 [options]

Options:
  --repo <owner/repo>            Required repository slug
  --pr <number>                  Required source PR number
  --target-branch <branch>       Target branch for new branch checkout (default: repo default branch)
  --source-base-branch <branch>  Optional override for PR source base branch used to compute exact PR diff
  --branch-prefix <prefix>       Branch prefix (default: copy-pr)
  --ssh-host <host>              SSH host alias (default: github.com)
  --api-host <host>              API host (default: api.github.com)
  --web-host <host>              Web host (default: github.com)
  --token-env <envvar>           Token env var for API (default: GITHUB_PERSONAL_ACCESS_TOKEN)
  --title <title>                PR title override
  --body <body>                  PR body override
  --create-pr                    Create PR via GitHub REST API after push
  --keep-workdir                 Keep /tmp working directory
  -h, --help                     Show help
USAGE
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

detect_pr_base_branch() {
  local api_host="$1"
  local repo="$2"
  local pr_number="$3"
  local token_env="$4"
  local token=""
  local response=""
  local base_ref=""

  token="${!token_env:-}"

  if [[ -n "$token" ]]; then
    response="$(curl -sS \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github+json" \
      "https://${api_host}/repos/${repo}/pulls/${pr_number}" || true)"
  else
    response="$(curl -sS \
      -H "Accept: application/vnd.github+json" \
      "https://${api_host}/repos/${repo}/pulls/${pr_number}" || true)"
  fi

  base_ref="$(printf '%s' "$response" | jq -r '.base.ref // empty' 2>/dev/null || true)"

  if [[ -n "$base_ref" ]]; then
    echo "$base_ref"
    return 0
  fi

  return 1
}

detect_repo_default_branch() {
  local ref=""
  local branch=""

  ref="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$ref" ]]; then
    branch="${ref#origin/}"
    if [[ -n "$branch" ]]; then
      echo "$branch"
      return 0
    fi
  fi

  branch="$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}' | head -n 1 || true)"
  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi

  return 1
}

get_parent_count() {
  local ref="$1"
  git rev-list --parents -n 1 "$ref" | awk '{print NF-1}'
}

REPO=""
PR_NUMBER=""
TARGET_BRANCH=""
SOURCE_BASE_BRANCH=""
BRANCH_PREFIX="copy-pr"
SSH_HOST="github.com"
API_HOST="api.github.com"
WEB_HOST="github.com"
TOKEN_ENV="GITHUB_PERSONAL_ACCESS_TOKEN"
PR_TITLE=""
PR_BODY=""
CREATE_PR=0
KEEP_WORKDIR=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --pr) PR_NUMBER="${2:-}"; shift 2 ;;
    --target-branch) TARGET_BRANCH="${2:-}"; shift 2 ;;
    --source-base-branch) SOURCE_BASE_BRANCH="${2:-}"; shift 2 ;;
    --branch-prefix) BRANCH_PREFIX="${2:-}"; shift 2 ;;
    --ssh-host) SSH_HOST="${2:-}"; shift 2 ;;
    --api-host) API_HOST="${2:-}"; shift 2 ;;
    --web-host) WEB_HOST="${2:-}"; shift 2 ;;
    --token-env) TOKEN_ENV="${2:-}"; shift 2 ;;
    --title) PR_TITLE="${2:-}"; shift 2 ;;
    --body) PR_BODY="${2:-}"; shift 2 ;;
    --create-pr) CREATE_PR=1; shift ;;
    --keep-workdir) KEEP_WORKDIR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$PR_NUMBER" ]]; then
  echo "--repo and --pr are required." >&2
  usage
  exit 1
fi

need_cmd git
need_cmd curl
need_cmd jq

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "PR number must be numeric." >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
NEW_BRANCH="${BRANCH_PREFIX}-${PR_NUMBER}-${TS}"
WORKDIR="$(mktemp -d "/tmp/pr-copy-${PR_NUMBER}-${TS}-XXXX")"

if [[ "$KEEP_WORKDIR" -eq 0 ]]; then
  trap 'rm -rf "$WORKDIR"' EXIT
fi

git clone --quiet "git@${SSH_HOST}:${REPO}.git" "$WORKDIR"
cd "$WORKDIR"

if [[ -z "$TARGET_BRANCH" ]]; then
  if TARGET_BRANCH="$(detect_repo_default_branch)"; then
    echo "[info] Auto-detected target_branch=${TARGET_BRANCH} from repository default branch"
  else
    echo "[error] Could not auto-detect repository default branch. Pass --target-branch explicitly." >&2
    exit 1
  fi
fi

git fetch origin "$TARGET_BRANCH" --quiet
git fetch origin "pull/${PR_NUMBER}/head:pr-${PR_NUMBER}-head" --quiet

PR_HEAD_REF="pr-${PR_NUMBER}-head"
PR_HEAD_PARENT_COUNT="$(get_parent_count "${PR_HEAD_REF}")"
DIFF_STRATEGY=""
DIFF_FROM=""
DIFF_TO=""
USE_CHERRY_PICK=0

if [[ "$PR_HEAD_PARENT_COUNT" -eq 1 ]]; then
  # Single-commit PR heads are best replayed directly to avoid base-branch drift.
  USE_CHERRY_PICK=1
  DIFF_STRATEGY="single-commit-cherry-pick"
else
  if [[ -z "$SOURCE_BASE_BRANCH" ]]; then
    if DETECTED_BASE_BRANCH="$(detect_pr_base_branch "$API_HOST" "$REPO" "$PR_NUMBER" "$TOKEN_ENV")"; then
      SOURCE_BASE_BRANCH="$DETECTED_BASE_BRANCH"
      echo "[info] Auto-detected source_base_branch=${SOURCE_BASE_BRANCH} from PR metadata"
    else
      echo "[error] Could not auto-detect PR base branch from PR metadata." >&2
      echo "[error] Reason: missing API access/token, PR not found, or API host mismatch." >&2
      exit 1
    fi
  fi

  git fetch origin "$SOURCE_BASE_BRANCH" --quiet

  # PR-exact diff is computed from the PR source base branch merge-base to PR head.
  MERGE_BASE="$(git merge-base "origin/${SOURCE_BASE_BRANCH}" "${PR_HEAD_REF}")"
  if [[ -z "$MERGE_BASE" ]]; then
    echo "Unable to calculate merge-base." >&2
    exit 1
  fi

  DIFF_FROM="$MERGE_BASE"
  DIFF_TO="$PR_HEAD_REF"
  DIFF_STRATEGY="head-vs-merge-base"

  if git diff --quiet "${DIFF_FROM}".."${DIFF_TO}"; then
    echo "[error] No PR diff found between merge-base and PR head." >&2
    echo "[error] Reason: PR may already be merged/empty, or metadata points to an unexpected head state." >&2
    exit 1
  fi
fi

echo "[info] repo=$REPO"
echo "[info] source_pr=$PR_NUMBER"
echo "[info] target_branch=$TARGET_BRANCH"
if [[ -n "$SOURCE_BASE_BRANCH" ]]; then
  echo "[info] source_base_branch=$SOURCE_BASE_BRANCH"
fi
echo "[info] pr_head_parent_count=$PR_HEAD_PARENT_COUNT"
echo "[info] branch=$NEW_BRANCH"
echo "[info] workdir=$WORKDIR"
echo "[info] diff_strategy=${DIFF_STRATEGY}"

git checkout -b "$NEW_BRANCH" "origin/${TARGET_BRANCH}" --quiet

if [[ "$USE_CHERRY_PICK" -eq 1 ]]; then
  if ! git cherry-pick -x "${PR_HEAD_REF}"; then
    echo "[error] Failed to cherry-pick PR head commit onto target branch '${TARGET_BRANCH}'." >&2
    echo "[error] Resolve conflicts manually or choose a different target/base combination." >&2
    exit 1
  fi
else
  PATCH_FILE="${WORKDIR}/pr-${PR_NUMBER}.patch"
  git diff --binary --find-renames "${DIFF_FROM}".."${DIFF_TO}" > "${PATCH_FILE}"

  if [[ ! -s "${PATCH_FILE}" ]]; then
    echo "No patch content found for PR #${PR_NUMBER} after applying strategy '${DIFF_STRATEGY}'."
    echo "Try checking if the PR actually changed files, or provide a different source base branch."
    exit 1
  fi

  if ! git apply --3way --index "${PATCH_FILE}"; then
    echo "[error] Failed to apply PR patch onto target branch '${TARGET_BRANCH}'."
    echo "[error] This usually means the PR changes do not cleanly apply to '${TARGET_BRANCH}'."
    echo "[error] Resolve conflicts manually or choose a different target/base combination."
    exit 1
  fi

  if git diff --cached --quiet; then
    echo "No changes found for PR #${PR_NUMBER} after applying strategy '${DIFF_STRATEGY}'."
    echo "Try checking if the PR actually changed files, or provide a different source base branch."
    exit 1
  fi

  git commit -m "Copy changes from PR #${PR_NUMBER} onto ${TARGET_BRANCH}" --quiet
fi
git push -u origin "$NEW_BRANCH" --quiet

echo "[ok] Pushed branch: $NEW_BRANCH"

echo "[info] Open PR URL: https://${WEB_HOST}/${REPO}/pull/new/${NEW_BRANCH}"

if [[ "$CREATE_PR" -eq 1 ]]; then
  TOKEN="${!TOKEN_ENV:-}"
  if [[ -z "$TOKEN" ]]; then
    echo "[warn] ${TOKEN_ENV} is empty. Skipping API PR creation."
    exit 0
  fi

  [[ -z "$PR_TITLE" ]] && PR_TITLE="Copy PR #${PR_NUMBER} changes to ${TARGET_BRANCH}"
  if [[ -z "$PR_BODY" ]]; then
    if [[ "$USE_CHERRY_PICK" -eq 1 ]]; then
      PR_BODY="This PR replays the single head commit from #${PR_NUMBER} onto a timestamped branch created from ${TARGET_BRANCH}."
    else
      PR_BODY="This PR copies file changes from #${PR_NUMBER} onto a timestamped branch created from ${TARGET_BRANCH}. Source base branch for PR diff: ${SOURCE_BASE_BRANCH}."
    fi
  fi

  PAYLOAD="$(jq -n \
    --arg title "$PR_TITLE" \
    --arg head "$NEW_BRANCH" \
    --arg base "$TARGET_BRANCH" \
    --arg body "$PR_BODY" \
    '{title:$title, head:$head, base:$base, body:$body}')"

  HTTP_CODE="$(curl -s -o /tmp/create_pr_resp.json -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -X POST "https://${API_HOST}/repos/${REPO}/pulls" \
    -d "$PAYLOAD")"

  if [[ "$HTTP_CODE" == "201" ]]; then
    echo "[ok] PR created: $(jq -r '.html_url' /tmp/create_pr_resp.json)"
  else
    echo "[warn] PR API creation failed (HTTP $HTTP_CODE)."
    cat /tmp/create_pr_resp.json
  fi
fi
