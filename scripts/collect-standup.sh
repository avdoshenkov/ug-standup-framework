#!/usr/bin/env bash
set -euo pipefail

# collect-standup.sh — standup data collection orchestrator
# Usage: collect-standup.sh [--since YYYY-MM-DD] [--refresh-sprint] [--date YYYY-MM-DD]
# Iterates enabled sources, runs each, merges output into logs/YYYY-MM-DD.json

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Load config
# shellcheck source=lib/config.sh
source "${PLUGIN_ROOT}/scripts/lib/config.sh"

DATA_DIR="${STANDUP_DATA_DIR}"
LOGS_DIR="${DATA_DIR}/logs"
SINCE_ARG=""
DATE_ARG=""
REFRESH_SPRINT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)  SINCE_ARG="$2"; shift 2 ;;
    --date)   DATE_ARG="$2"; shift 2 ;;
    --refresh-sprint) REFRESH_SPRINT=true; shift ;;
    *) echo >&2 "[standup] Unknown argument: $1"; shift ;;
  esac
done

# Resolve date and since
TODAY="$(date "+%Y-%m-%d")"
TARGET_DATE="${DATE_ARG:-$TODAY}"

resolve_since() {
  local state_file="${DATA_DIR}/config/state.json"
  local last_run=""
  if [[ -f "$state_file" ]]; then
    last_run="$(jq -r '.last_run // empty' "$state_file" 2>/dev/null || true)"
  fi
  if [[ -n "$last_run" ]]; then
    echo "$last_run"; return
  fi
  local dow
  dow="$(date +%u)"
  if [[ "$dow" == "1" ]]; then
    if date --version >/dev/null 2>&1; then
      date -d "last friday 00:00:00" --iso-8601=seconds
    else
      date -v-fri -v0H -v0M -v0S "+%Y-%m-%dT%H:%M:%S%z"
    fi
  else
    if date --version >/dev/null 2>&1; then
      date -d "yesterday 00:00:00" --iso-8601=seconds
    else
      date -v-1d -v0H -v0M -v0S "+%Y-%m-%dT%H:%M:%S%z"
    fi
  fi
}

SINCE="${SINCE_ARG:-$(resolve_since)}"
echo >&2 "[standup] Collecting for date=${TARGET_DATE}, since=${SINCE}"

command -v jq >/dev/null 2>&1 || { echo >&2 "[standup] FATAL: jq not found"; exit 1; }
mkdir -p "$LOGS_DIR"

# Determine execution mode (cloud sessions set STANDUP_CLOUD_MODE=true or CC_CLOUD=true)
MODE="local"
[[ "${STANDUP_CLOUD_MODE:-}" == "true" || "${CC_CLOUD:-}" == "true" ]] && MODE="cloud"

# Parse enabled sources (JSON array or fallback default)
ENABLED_SOURCES_JSON="${STANDUP_ENABLED_SOURCES:-[\"jira\",\"github\",\"git\",\"slack-self\"]}"
# bash 3 compatible (macOS ships bash 3; readarray requires bash 4+)
ENABLED_SOURCES=()
while IFS= read -r _src; do
  [[ -n "$_src" ]] && ENABLED_SOURCES+=("$_src")
done < <(echo "$ENABLED_SOURCES_JSON" | jq -r '.[]' 2>/dev/null || printf 'jira\ngithub\ngit\nslack-self\n')

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCES_JSON="{}"

for SOURCE_NAME in "${ENABLED_SOURCES[@]}"; do
  [[ -z "$SOURCE_NAME" ]] && continue
  echo >&2 "[standup] Processing source: ${SOURCE_NAME}"

  # Resolve source dir: prefer data-repo override, fall back to plugin built-in
  SOURCE_DIR=""
  if [[ -d "${DATA_DIR}/sources/${SOURCE_NAME}" ]]; then
    SOURCE_DIR="${DATA_DIR}/sources/${SOURCE_NAME}"
  elif [[ -d "${PLUGIN_ROOT}/scripts/sources/${SOURCE_NAME}" ]]; then
    SOURCE_DIR="${PLUGIN_ROOT}/scripts/sources/${SOURCE_NAME}"
  else
    echo >&2 "[standup]   WARNING: source dir not found for '${SOURCE_NAME}' — skipping"
    SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "source dir not found" '. + {($k): {skipped: $v}}')"
    continue
  fi

  MANIFEST="${SOURCE_DIR}/source.json"
  if [[ ! -f "$MANIFEST" ]]; then
    echo >&2 "[standup]   WARNING: source.json missing in ${SOURCE_DIR} — skipping"
    SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "source.json missing" '. + {($k): {skipped: $v}}')"
    continue
  fi

  # Check available_in mode gating
  AVAILABLE_IN="$(jq -r '.available_in // ["local","cloud"] | join(",")' "$MANIFEST" 2>/dev/null || echo "local,cloud")"
  if [[ "$AVAILABLE_IN" != *"$MODE"* ]]; then
    echo >&2 "[standup]   Skipping ${SOURCE_NAME} (not available in ${MODE})"
    SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "not available in ${MODE}" '. + {($k): {skipped: $v}}')"
    continue
  fi

  # Check required env vars
  REQUIRES_ENV="$(jq -r '.requires_env // [] | .[]' "$MANIFEST" 2>/dev/null || true)"
  MISSING_VARS=""
  while IFS= read -r REQ_VAR; do
    [[ -z "$REQ_VAR" ]] && continue
    if [[ -z "${!REQ_VAR:-}" ]]; then
      MISSING_VARS="${MISSING_VARS} ${REQ_VAR}"
    fi
  done <<< "$REQUIRES_ENV"

  if [[ -n "$MISSING_VARS" ]]; then
    echo >&2 "[standup]   Skipping ${SOURCE_NAME} (missing config:${MISSING_VARS})"
    SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "missing config:${MISSING_VARS}" '. + {($k): {skipped: $v}}')"
    continue
  fi

  # Execute shell-kind sources
  KIND="$(jq -r '.kind // "shell"' "$MANIFEST" 2>/dev/null || echo "shell")"
  if [[ "$KIND" == "shell" ]]; then
    FETCH_SCRIPT="${SOURCE_DIR}/lib/fetch.sh"
    if [[ ! -f "$FETCH_SCRIPT" ]]; then
      echo >&2 "[standup]   WARNING: lib/fetch.sh missing in ${SOURCE_DIR}"
      SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "lib/fetch.sh missing" '. + {($k): {skipped: $v}}')"
      continue
    fi
    chmod +x "$FETCH_SCRIPT" 2>/dev/null || true
    OUT_FILE="${TMP_DIR}/${SOURCE_NAME}.json"
    if bash "$FETCH_SCRIPT" "$TARGET_DATE" > "$OUT_FILE" 2>"${TMP_DIR}/${SOURCE_NAME}.err"; then
      if jq empty "$OUT_FILE" 2>/dev/null; then
        SOURCE_RESULT="$(cat "$OUT_FILE")"
        SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --argjson v "$SOURCE_RESULT" '. + {($k): $v}')"
        echo >&2 "[standup]   ${SOURCE_NAME}: OK"
      else
        echo >&2 "[standup]   ${SOURCE_NAME}: invalid JSON output"
        SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "invalid JSON output" '. + {($k): {error: $v}}')"
      fi
    else
      ERR="$(tail -1 "${TMP_DIR}/${SOURCE_NAME}.err" 2>/dev/null || echo "fetch.sh exited non-zero")"
      echo >&2 "[standup]   ${SOURCE_NAME}: ERROR: ${ERR}"
      SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "$ERR" '. + {($k): {error: $v}}')"
    fi
  elif [[ "$KIND" == "mcp" ]]; then
    echo >&2 "[standup]   ${SOURCE_NAME}: MCP-kind — must be executed by orchestrator skill (run.md)"
    SOURCES_JSON="$(echo "$SOURCES_JSON" | jq -c --arg k "$SOURCE_NAME" --arg v "mcp-kind: execute via skill orchestrator" '. + {($k): {skipped: $v}}')"
  fi
done

# Write log file
NOW_ISO="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"
OUTPUT_FILE="${LOGS_DIR}/${TARGET_DATE}.json"

MERGED="$(jq -n \
  --arg collected_at "$NOW_ISO" \
  --arg since "$SINCE" \
  --arg mode "$MODE" \
  --argjson sources "$SOURCES_JSON" \
  '{collected_at: $collected_at, since: $since, mode: $mode, sources: $sources}')"

echo "$MERGED" > "$OUTPUT_FILE"
echo >&2 "[standup] Written: ${OUTPUT_FILE}"

# Update state.json
STATE_FILE="${DATA_DIR}/config/state.json"
SPRINT_OBJ="$(echo "$MERGED" | jq -c '.sources.jira.sprint // null' 2>/dev/null || echo 'null')"
SPRINT_OBJ_WITH_TS="$(echo "$SPRINT_OBJ" | jq -c --arg ts "$NOW_ISO" 'if . != null then . + {fetched_at: $ts} else null end' 2>/dev/null || echo 'null')"

if [[ -f "$STATE_FILE" ]]; then
  jq --arg ts "$NOW_ISO" --argjson sprint "$SPRINT_OBJ_WITH_TS" \
    '.last_run = $ts | if $sprint != null then .current_sprint = $sprint else . end' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE" \
    && echo >&2 "[standup] Updated state.json last_run=${NOW_ISO}" \
    || echo >&2 "[standup] WARNING: failed to update state.json"
else
  mkdir -p "$(dirname "$STATE_FILE")"
  jq -n --arg ts "$NOW_ISO" --argjson sprint "$SPRINT_OBJ_WITH_TS" \
    '{last_run: $ts} | if $sprint != null then .current_sprint = $sprint else . end' \
    > "$STATE_FILE" \
    && echo >&2 "[standup] Created state.json" \
    || echo >&2 "[standup] WARNING: failed to create state.json"
fi

echo >&2 "[standup] =========================================="
echo >&2 "[standup] Collection complete: ${TARGET_DATE}"
echo >&2 "[standup] =========================================="
