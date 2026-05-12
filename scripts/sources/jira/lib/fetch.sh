#!/usr/bin/env bash
set -euo pipefail

# jira/lib/fetch.sh — collect Jira sprint + activity data
# Usage: fetch.sh <YYYY-MM-DD> [--refresh-sprint]
# Reads: STANDUP_JIRA_BOARD_ID, STANDUP_JIRA_PROJECT, STANDUP_JIRA_ACCOUNT_ID (from env)
# Outputs JSON to stdout: { "sprint": {...}, "events": [...] }
# Errors: { "sprint": null, "events": [], "error": "<message>" }

DATE="${1:-}"
REFRESH_SPRINT=false
[[ "${2:-}" == "--refresh-sprint" ]] && REFRESH_SPRINT=true

BOARD_ID="${STANDUP_JIRA_BOARD_ID:-}"
TTL_DAYS=3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${STANDUP_DATA_DIR:-$(cd "${SCRIPT_DIR}/../../../../.." && pwd)}"
STATE_FILE="${DATA_DIR}/config/state.json"

if [[ -z "$DATE" ]]; then
  echo >&2 "[jira] date argument required (YYYY-MM-DD)"
  echo '{"sprint": null, "events": [], "error": "date argument missing"}'
  exit 0
fi

[[ -z "$BOARD_ID" ]] && { echo >&2 "[jira] STANDUP_JIRA_BOARD_ID not set"; echo '{"sprint":null,"events":[],"error":"STANDUP_JIRA_BOARD_ID not set"}'; exit 0; }

SINCE="${DATE}T00:00:00+00:00"

fail() {
  echo >&2 "[jira] ERROR: $1"
  printf '{"sprint": null, "events": [], "error": %s}\n' "$(jq -n --arg m "$1" '$m')"
  exit 0
}

command -v jq   >/dev/null 2>&1 || fail "jq not found in PATH"
command -v acli >/dev/null 2>&1 || fail "acli not found in PATH"

echo >&2 "[jira] Collecting (date=${DATE}, board=${BOARD_ID}, refresh=${REFRESH_SPRINT})"

# ─── 1. Sprint cache ──────────────────────────────────────────────────────────
SPRINT_ID=""
SPRINT_NAME=""
USE_CACHE=false

if [[ -f "$STATE_FILE" ]]; then
  CACHED="$(jq -c '.current_sprint // empty' "$STATE_FILE" 2>/dev/null || true)"
  if [[ -n "$CACHED" && "$REFRESH_SPRINT" == "false" ]]; then
    FETCHED_AT="$(echo "$CACHED" | jq -r '.fetched_at // empty')"
    if [[ -n "$FETCHED_AT" ]]; then
      FETCHED_EP="$(date -j -f "%Y-%m-%dT%H:%M:%S" "${FETCHED_AT%%+*}" "+%s" 2>/dev/null \
        || date -d "$FETCHED_AT" "+%s" 2>/dev/null || echo 0)"
      NOW_EP="$(date "+%s")"
      if (( NOW_EP - FETCHED_EP < TTL_DAYS * 86400 )); then
        USE_CACHE=true
        SPRINT_ID="$(echo "$CACHED" | jq -r '.id // empty')"
        SPRINT_NAME="$(echo "$CACHED" | jq -r '.name // empty')"
        echo >&2 "[jira] Using cached sprint: ${SPRINT_NAME} (id=${SPRINT_ID})"
      fi
    fi
  fi
fi

if [[ "$USE_CACHE" == "false" ]]; then
  echo >&2 "[jira] Fetching active sprint from board ${BOARD_ID}..."
  SPRINTS_JSON="$(acli jira board list-sprints --id "$BOARD_ID" --state active --json 2>/dev/null)" \
    || fail "acli board list-sprints failed"
  SPRINT_ID="$(echo "$SPRINTS_JSON" | jq -r '(if type == "array" then . else (.sprints // []) end)[0].id // empty')" \
    || fail "Failed to parse sprint id"
  SPRINT_NAME="$(echo "$SPRINTS_JSON" | jq -r '(if type == "array" then . else (.sprints // []) end)[0].name // empty')" || true
  [[ -z "$SPRINT_ID" ]] && fail "No active sprint found on board ${BOARD_ID}"
  echo >&2 "[jira] Found sprint: ${SPRINT_NAME} (id=${SPRINT_ID})"
fi

# ─── 2. Sprint work items ─────────────────────────────────────────────────────
WORKITEMS_RAW="$(acli jira workitem search \
  --jql "sprint = ${SPRINT_ID} AND assignee = currentUser()" \
  --json 2>/dev/null)" \
  || { echo >&2 "[jira] WARNING: sprint workitem search failed"; WORKITEMS_RAW="[]"; }

SPRINT_TASKS="$(echo "$WORKITEMS_RAW" | jq -c '
  if type == "array" then map({key: (.key // .id // ""), summary: (.fields.summary // .summary // ""), status: (.fields.status.name // .status // ""), url: (.self // ""), updated_today: false})
  else [] end
' 2>/dev/null || echo "[]")"

SPRINT_OBJ="$(jq -n \
  --argjson id "$(echo "$SPRINT_ID" | jq -R 'tonumber? // 0')" \
  --arg name "$SPRINT_NAME" \
  --argjson board "$BOARD_ID" \
  --argjson tasks "$SPRINT_TASKS" \
  '{id: $id, name: $name, board_id: $board, tasks: $tasks}')"

# ─── 3. Issues updated since DATE ────────────────────────────────────────────
SEARCH_RAW="$(acli jira workitem search \
  --jql "assignee = currentUser() AND updated >= '${DATE}'" \
  --json 2>/dev/null)" \
  || { echo >&2 "[jira] WARNING: workitem search failed"; SEARCH_RAW="[]"; }

CANDIDATES="$(echo "$SEARCH_RAW" | jq -c '
  if type == "array" then .
  elif type == "object" and ((.issues // .values // empty) | type) == "array" then (.issues // .values)
  else [] end
' 2>/dev/null || echo "[]")"

CANDIDATE_KEYS="$(echo "$CANDIDATES" | jq -r '.[].key // .[].id // empty' 2>/dev/null || true)"

# ─── 4. Per-issue detail ──────────────────────────────────────────────────────
EVENTS="[]"
MY_ACCOUNT_ID="${STANDUP_JIRA_ACCOUNT_ID:-}"

if [[ -z "$MY_ACCOUNT_ID" && -f "$STATE_FILE" ]]; then
  MY_ACCOUNT_ID="$(jq -r '.my_jira_account_id // empty' "$STATE_FILE" 2>/dev/null || true)"
fi

_BOOTSTRAPPED=false

if [[ -n "$CANDIDATE_KEYS" ]]; then
  while IFS= read -r KEY; do
    [[ -z "$KEY" ]] && continue
    echo >&2 "[jira]   Processing ${KEY}..."

    DETAIL="$(acli jira workitem view "$KEY" --expand changelog --json 2>/dev/null \
      || acli jira workitem view "$KEY" --json 2>/dev/null)" \
      || { echo >&2 "[jira]   WARNING: view ${KEY} failed"; continue; }

    if [[ -z "$MY_ACCOUNT_ID" && "$_BOOTSTRAPPED" == "false" ]]; then
      BOOTSTRAPPED_ID="$(echo "$DETAIL" | jq -r '.fields.assignee.accountId // empty' 2>/dev/null || true)"
      if [[ -n "$BOOTSTRAPPED_ID" ]]; then
        MY_ACCOUNT_ID="$BOOTSTRAPPED_ID"
        _BOOTSTRAPPED=true
        echo >&2 "[jira]   Bootstrapped my_jira_account_id=${MY_ACCOUNT_ID}"
        if [[ -f "$STATE_FILE" ]]; then
          jq --arg id "$MY_ACCOUNT_ID" '.my_jira_account_id = $id' "$STATE_FILE" > "${STATE_FILE}.tmp" \
            && mv "${STATE_FILE}.tmp" "$STATE_FILE" \
            || echo >&2 "[jira]   WARNING: failed to persist my_jira_account_id"
        fi
      fi
    fi

    STATUS_CHANGES="$(echo "$DETAIL" | jq -c --arg since "$SINCE" '
      [(.changelog.histories // [])[] | . as $h | select($h.created >= $since) | $h.items[] | select(.field == "status") | {from: .fromString, to: .toString, at: $h.created}]
    ' 2>/dev/null || echo "[]")"

    SUMMARY="$(echo "$DETAIL" | jq -r '.fields.summary // .summary // ""' 2>/dev/null || true)"
    STATUS="$(echo "$DETAIL" | jq -r '.fields.status.name // .status // ""' 2>/dev/null || true)"
    SELF_URL="$(echo "$DETAIL" | jq -r '.self // ""' 2>/dev/null || true)"
    UPDATED_AT="$(echo "$DETAIL" | jq -r '.fields.updated // .updated // ""' 2>/dev/null || true)"

    RESOLVED='["Done","Готово","Closed","Resolved","Ready for release","Ready for QA"]'
    CLOSED_TODAY="$(jq -n --arg status "$STATUS" --arg updated "$UPDATED_AT" --arg since "$SINCE" \
      --argjson resolved "$RESOLVED" '($resolved | index($status)) != null and ($updated >= $since)' 2>/dev/null || echo "false")"

    COMMENTS_BY_ME="[]"
    COMMENTS_TO_ME="[]"
    if [[ -n "$MY_ACCOUNT_ID" ]]; then
      COMMENTS_BY_ME="$(echo "$DETAIL" | jq -c --arg since "$SINCE" --arg me "$MY_ACCOUNT_ID" '
        [(.fields.comment.comments // [])[] | select(.created >= $since) | select(.author.accountId == $me) | {at: .created, body: (.body // "")}]
      ' 2>/dev/null || echo "[]")"
      COMMENTS_TO_ME="$(echo "$DETAIL" | jq -c --arg since "$SINCE" --arg me "$MY_ACCOUNT_ID" '
        [(.fields.comment.comments // [])[] | select(.created >= $since) | select(.author.accountId != $me) | {at: .created, author: .author.displayName, body: (.body // "")}]
      ' 2>/dev/null || echo "[]")"
    fi

    ISSUE_OBJ="$(jq -n \
      --arg key "$KEY" --arg summary "$SUMMARY" --arg url "$SELF_URL" --arg status "$STATUS" \
      --argjson sc "$STATUS_CHANGES" --argjson cbm "$COMMENTS_BY_ME" --argjson ctm "$COMMENTS_TO_ME" \
      --argjson closed_today "$CLOSED_TODAY" \
      '{key: $key, summary: $summary, url: $url, status: $status, closed_today: $closed_today,
        status_changes: $sc, comments_by_me: $cbm, comments_to_me: $ctm}')"

    EVENTS="$(echo "$EVENTS" | jq -c --argjson obj "$ISSUE_OBJ" '. + [$obj]')"
  done <<< "$CANDIDATE_KEYS"
fi

echo >&2 "[jira] Done."
jq -n --argjson sprint "$SPRINT_OBJ" --argjson events "$EVENTS" '{sprint: $sprint, events: $events}'
