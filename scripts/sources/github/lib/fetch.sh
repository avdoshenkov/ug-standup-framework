#!/usr/bin/env bash
set -euo pipefail

# github/lib/fetch.sh — collect GitHub commits and PR activity
# Usage: fetch.sh <YYYY-MM-DD>
# Reads: STANDUP_GH_ORG, STANDUP_GH_REPOS (space or colon separated, from env)
# Outputs JSON to stdout: { "events": [...] }
# Errors: { "events": [], "error": "<message>" }

DATE="${1:-}"

if [[ -z "$DATE" ]]; then
  echo >&2 "[github] date argument required (YYYY-MM-DD)"
  echo '{"events": [], "error": "date argument missing"}'
  exit 0
fi

GH_ORG="${STANDUP_GH_ORG:-}"
GH_REPOS_RAW="${STANDUP_GH_REPOS:-}"

fail() {
  echo >&2 "[github] ERROR: $1"
  printf '{"events": [], "error": %s}\n' "$(jq -n --arg m "$1" '$m')"
  exit 0
}

command -v jq >/dev/null 2>&1 || fail "jq not found in PATH"
command -v gh >/dev/null 2>&1 || fail "gh not found in PATH"

# Build repo list: STANDUP_GH_REPOS may be JSON array, colon-separated, or space-separated
REPOS=()
if [[ -n "$GH_REPOS_RAW" ]]; then
  if echo "$GH_REPOS_RAW" | jq -e 'type == "array"' >/dev/null 2>&1; then
    # JSON array
    while IFS= read -r r; do REPOS+=("$r"); done < <(echo "$GH_REPOS_RAW" | jq -r '.[]')
  else
    # Colon or space separated — normalise to space
    IFS=': ' read -ra REPOS <<< "$GH_REPOS_RAW"
  fi
fi

# If no repos configured, fall back to owner search only (commits)
if [[ ${#REPOS[@]} -eq 0 && -z "$GH_ORG" ]]; then
  fail "Neither STANDUP_GH_REPOS nor STANDUP_GH_ORG is set"
fi

SINCE_DATE="$DATE"
echo >&2 "[github] Collecting (date=${DATE}, org=${GH_ORG:-<unset>}, repos=${#REPOS[@]})"

# ─── 1. Commits ───────────────────────────────────────────────────────────────
echo >&2 "[github] Fetching commits..."
COMMITS_ARGS=(search commits --author=@me --committer-date=">=${SINCE_DATE}" --json repository,sha,commit,url --limit 200)
[[ -n "$GH_ORG" ]] && COMMITS_ARGS+=(--owner="$GH_ORG")

COMMITS_RAW="$(gh "${COMMITS_ARGS[@]}" 2>&1)" \
  || { echo >&2 "[github] WARNING: gh search commits failed: ${COMMITS_RAW}"; COMMITS_RAW="[]"; }

COMMITS="$(echo "$COMMITS_RAW" | jq -c '
  if type == "array" then
    map({type: "commit", repo: .repository.nameWithOwner, sha: .sha, message: .commit.message, url: .url, at: .commit.author.date})
  else [] end
' 2>/dev/null || echo "[]")"

# ─── 2. PRs per repo ──────────────────────────────────────────────────────────
echo >&2 "[github] Fetching PRs..."
ALL_PRS="[]"

for REPO in "${REPOS[@]}"; do
  [[ -z "$REPO" ]] && continue
  # Prefix org if needed
  [[ "$REPO" != */* && -n "$GH_ORG" ]] && REPO="${GH_ORG}/${REPO}"
  echo >&2 "[github]   Repo: ${REPO}"

  AUTHORED_RAW="$(gh pr list --author @me --state all \
    --search "updated:>=${SINCE_DATE}" \
    --json number,title,state,url,createdAt,mergedAt,closedAt \
    --repo "$REPO" --limit 100 2>&1)" \
    || { echo >&2 "[github]   WARNING: pr list (authored) failed for ${REPO}"; AUTHORED_RAW="[]"; }

  REVIEWED_RAW="$(gh pr list --state all \
    --search "reviewed-by:@me updated:>=${SINCE_DATE}" \
    --json number,title,state,url,createdAt,mergedAt,closedAt \
    --repo "$REPO" --limit 100 2>&1)" \
    || { echo >&2 "[github]   WARNING: pr list (reviewed) failed for ${REPO}"; REVIEWED_RAW="[]"; }

  AUTHORED_PRS="$(echo "$AUTHORED_RAW" | jq -c --arg repo "$REPO" --arg since "$SINCE_DATE" '
    if type == "array" then map({type: "pr", repo: $repo, number: .number, title: .title, state: .state, url: .url,
      action: (if (.mergedAt // "" | . != "" and . >= $since) then "merged" elif (.closedAt // "" | . != "" and . >= $since) then "closed" elif (.createdAt // "" | . != "" and . >= $since) then "opened" else "updated" end),
      at: (if (.mergedAt // "" != "") then .mergedAt elif (.closedAt // "" != "") then .closedAt else .createdAt end)})
    else [] end
  ' 2>/dev/null || echo "[]")"

  AUTHORED_NUMS="$(echo "$AUTHORED_PRS" | jq '[.[].number]' 2>/dev/null || echo "[]")"

  REVIEWED_PRS="$(echo "$REVIEWED_RAW" | jq -c --arg repo "$REPO" --argjson an "$AUTHORED_NUMS" '
    if type == "array" then
      map(select(.number as $n | ($an | index($n)) == null) | {type: "pr", repo: $repo, number: .number, title: .title, state: .state, url: .url, action: "reviewed",
        at: (if (.mergedAt // "" != "") then .mergedAt elif (.closedAt // "" != "") then .closedAt else .createdAt end)})
    else [] end
  ' 2>/dev/null || echo "[]")"

  REPO_PRS="$(jq -n --argjson a "$AUTHORED_PRS" --argjson r "$REVIEWED_PRS" '$a + $r')"
  ALL_PRS="$(jq -n --argjson e "$ALL_PRS" --argjson n "$REPO_PRS" '$e + $n')"
done

# ─── Output ───────────────────────────────────────────────────────────────────
echo >&2 "[github] Done."
jq -n --argjson commits "$COMMITS" --argjson prs "$ALL_PRS" '{events: ($commits + $prs)}'
