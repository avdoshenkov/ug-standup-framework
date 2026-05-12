#!/usr/bin/env bash
set -euo pipefail

# git/lib/fetch.sh — collect local git repo activity
# Usage: fetch.sh <YYYY-MM-DD>
# Reads: STANDUP_LOCAL_REPOS (colon-separated paths, from .env)
# Outputs JSON to stdout: { "events": [...] }
# Errors: { "events": [], "error": "<message>" }

DATE="${1:-}"

if [[ -z "$DATE" ]]; then
  echo >&2 "[git] date argument required (YYYY-MM-DD)"
  echo '{"events": [], "error": "date argument missing"}'
  exit 0
fi

REPOS_RAW="${STANDUP_LOCAL_REPOS:-}"
SINCE="${DATE}T00:00:00"

fail() {
  echo >&2 "[git] ERROR: $1"
  printf '{"events": [], "error": %s}\n' "$(jq -n --arg m "$1" '$m')"
  exit 0
}

command -v jq  >/dev/null 2>&1 || fail "jq not found in PATH"
command -v git >/dev/null 2>&1 || fail "git not found in PATH"

echo >&2 "[git] Collecting local repos (date=${DATE})"

# Parse colon-separated repo paths
REPO_PATHS=()
if [[ -n "$REPOS_RAW" ]]; then
  IFS=':' read -ra REPO_PATHS <<< "$REPOS_RAW"
fi

if [[ ${#REPO_PATHS[@]} -eq 0 ]]; then
  echo >&2 "[git] No repos configured in STANDUP_LOCAL_REPOS"
  echo '{"events": []}'
  exit 0
fi

EVENTS="[]"

for REPO_PATH in "${REPO_PATHS[@]}"; do
  [[ -z "$REPO_PATH" ]] && continue
  echo >&2 "[git]   Processing: ${REPO_PATH}"

  if [[ ! -d "$REPO_PATH" ]]; then
    echo >&2 "[git]   SKIP: path not found: ${REPO_PATH}"
    ENTRY="$(jq -n --arg repo "$REPO_PATH" --arg err "path not found" '{type:"git_repo_error",repo:$repo,error:$err}')"
    EVENTS="$(jq -n --argjson e "$EVENTS" --argjson v "$ENTRY" '$e + [$v]')"
    continue
  fi

  if ! git -C "$REPO_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    echo >&2 "[git]   SKIP: not a git repo: ${REPO_PATH}"
    ENTRY="$(jq -n --arg repo "$REPO_PATH" --arg err "not a git repository" '{type:"git_repo_error",repo:$repo,error:$err}')"
    EVENTS="$(jq -n --argjson e "$EVENTS" --argjson v "$ENTRY" '$e + [$v]')"
    continue
  fi

  AUTHOR_EMAIL="$(git -C "$REPO_PATH" config user.email 2>/dev/null \
    || git config --global user.email 2>/dev/null || echo "")"
  CURRENT_BRANCH="$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

  COMMITS_RAW=""
  if [[ -n "$AUTHOR_EMAIL" ]]; then
    COMMITS_RAW="$(git -C "$REPO_PATH" log --author="$AUTHOR_EMAIL" --since="$SINCE" \
      --pretty=format:'%H|%s|%aI' 2>/dev/null || true)"
  else
    COMMITS_RAW="$(git -C "$REPO_PATH" log --since="$SINCE" \
      --pretty=format:'%H|%s|%aI' 2>/dev/null || true)"
  fi

  COMMITS_JSON="[]"
  if [[ -n "$COMMITS_RAW" ]]; then
    COMMITS_JSON="$(echo "$COMMITS_RAW" | awk -F'|' '
      NF >= 3 {
        sha = $1; msg = $2
        for (i = 3; i < NF; i++) msg = msg "|" $i
        at = $NF
        gsub(/\\/, "\\\\", msg); gsub(/"/, "\\\"", msg)
        print "{\"sha\":\"" sha "\",\"message\":\"" msg "\",\"at\":\"" at "\"}"
      }
    ' | jq -sc '.' 2>/dev/null || echo "[]")"
  fi

  STATUS_OUT="$(git -C "$REPO_PATH" status --porcelain 2>/dev/null || true)"
  UNCOMMITTED=false
  [[ -n "$STATUS_OUT" ]] && UNCOMMITTED=true

  UNPUSHED_BRANCHES="$(git -C "$REPO_PATH" for-each-ref \
    --format='%(refname:short) %(upstream:track)' refs/heads/ 2>/dev/null \
    | awk '{branch=$1; track=$2; if (track=="" || track~/\[ahead/) print branch}' || true)"

  UNPUSHED_JSON="$(printf '%s\n' "$UNPUSHED_BRANCHES" | jq -Rsc 'split("\n")|map(select(.!=""))' 2>/dev/null || echo "[]")"

  ENTRY="$(jq -n \
    --arg repo "$REPO_PATH" --arg branch "$CURRENT_BRANCH" \
    --argjson commits "$COMMITS_JSON" --argjson uncommitted "$UNCOMMITTED" --argjson unpushed "$UNPUSHED_JSON" \
    '{type:"git_repo",repo:$repo,branch:$branch,commits:$commits,uncommitted_changes:$uncommitted,unpushed_branches:$unpushed}')"

  EVENTS="$(jq -n --argjson e "$EVENTS" --argjson v "$ENTRY" '$e + [$v]')"
  echo >&2 "[git]   Done: ${REPO_PATH} ($(echo "$COMMITS_JSON" | jq 'length') commits)"
done

echo >&2 "[git] Done."
jq -n --argjson events "$EVENTS" '{events: $events}'
