#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  test_gh_auth.sh --repo owner/repo [options]

Options:
  --repo <owner/repo>   Repository slug (or set GITHUB_ORG + GITHUB_REPO in .env)
  --pr <number>         Optional: also verify PR read access
  --check-create-pr     Optional: probe PR create permission (safe, no PR created)
  -h, --help            Show help
USAGE
}

REPO=""
PR_NUMBER=""
CHECK_CREATE_PR=0

# --- Load .env from repo root (4 levels above this script's directory) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck source=/dev/null
  set -o allexport; source "${REPO_ROOT}/.env"; set +o allexport
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --pr) PR_NUMBER="${2:-}"; shift 2 ;;
    --check-create-pr) CHECK_CREATE_PR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# --- Env var fallback for --repo ---
if [[ -z "$REPO" && -n "${GITHUB_ORG:-}" && -n "${GITHUB_REPO:-}" ]]; then
  REPO="${GITHUB_ORG}/${GITHUB_REPO}"
  echo "[info] repo resolved from .env: ${REPO}"
fi

if [[ -z "$REPO" ]]; then
  echo "--repo is required." >&2
  usage
  exit 1
fi

# 1. Check gh CLI is authenticated
if ! GH_USER="$(gh auth status --active 2>&1 | grep -oP '(?<=Logged in to github\.com account )\S+' || true)"; then
  GH_USER=""
fi
if [[ -z "$GH_USER" ]]; then
  # Fallback: use gh api to get authenticated user
  GH_USER="$(gh api user --jq '.login' 2>/dev/null || true)"
fi

if [[ -z "$GH_USER" ]]; then
  echo "[error] gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi
echo "[ok] gh CLI authenticated as: ${GH_USER}"

# 2. Check repository read access
if gh repo view "${REPO}" --json name --jq '.name' >/dev/null 2>&1; then
  echo "[ok] Repository accessible: ${REPO}"
else
  echo "[error] Repository not accessible: ${REPO}" >&2
  echo "[error] Check that the repo exists and gh has access." >&2
  exit 1
fi

# 3. Optional: check PR read access
if [[ -n "$PR_NUMBER" ]]; then
  if gh pr view "${PR_NUMBER}" --repo "${REPO}" --json number --jq '.number' >/dev/null 2>&1; then
    echo "[ok] PR read access works: #${PR_NUMBER}"
  else
    echo "[error] Could not read PR #${PR_NUMBER} from ${REPO}" >&2
    echo "[error] Check that the PR exists and the token has read access." >&2
    exit 1
  fi
fi

# 4. Optional: probe PR create permission (safe — invalid refs cause HTTP 422, not 403/404)
if [[ "$CHECK_CREATE_PR" -eq 1 ]]; then
  PROBE_OUTPUT="$(gh api \
    --method POST \
    "/repos/${REPO}/pulls" \
    --field title="auth-probe-$(date +%s)" \
    --field head="__nonexistent_auth_probe__" \
    --field base="__nonexistent_auth_probe__" \
    --field body="" 2>&1 || true)"

  # HTTP 422 = validation failure (auth OK, refs just don't exist — expected)
  # HTTP 403/404 = auth or permission problem
  if echo "$PROBE_OUTPUT" | grep -q "Unprocessable Entity\|422\|Invalid value for"; then
    echo "[ok] PR create permission: auth accepted (expected 422 validation error)"
  elif echo "$PROBE_OUTPUT" | grep -q "403\|404\|Not Found\|Resource not accessible"; then
    echo "[error] PR create permission denied (HTTP 403/404). Grant Pull Requests: Read & Write." >&2
    exit 1
  else
    echo "[warn] PR create probe returned unexpected response:"
    echo "$PROBE_OUTPUT"
  fi
fi

echo "[ok] All checks passed."
