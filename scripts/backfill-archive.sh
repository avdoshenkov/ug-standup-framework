#!/usr/bin/env bash
set -euo pipefail

# backfill-archive.sh — validates prerequisites for Slack-based archive backfill
# Usage: ./scripts/backfill-archive.sh
#
# Checks that config and user ID are ready, then instructs how to run /standup-archive
# in Claude Code (which has MCP Slack access).

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Load config
# shellcheck source=lib/config.sh
source "${PLUGIN_ROOT}/scripts/lib/config.sh"

DATA_DIR="${STANDUP_DATA_DIR}"
STATE_FILE="${DATA_DIR}/config/state.json"
ARCHIVE_DIR="${DATA_DIR}/archive"

if [[ ! -f "${STATE_FILE}" ]]; then
  echo >&2 "[backfill] ERROR: config/state.json not found"
  echo >&2 "           Run ./scripts/collect-standup.sh first to create it."
  exit 1
fi

command -v jq &>/dev/null || { echo >&2 "[backfill] ERROR: jq required but not installed"; exit 1; }

MY_USER_ID="${STANDUP_SLACK_USER_ID:-$(jq -r '.my_user_id // empty' "${STATE_FILE}" 2>/dev/null || true)}"

if [[ -z "${MY_USER_ID}" ]]; then
  echo >&2 "[backfill] ERROR: Slack user ID not found"
  echo >&2 "           Set STANDUP_SLACK_USER_ID in config/local.json or run /standup first."
  exit 1
fi

ARCHIVE_COUNT=0
if [[ -d "${ARCHIVE_DIR}" ]]; then
  ARCHIVE_COUNT="$(find "${ARCHIVE_DIR}" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
fi

CHANNEL_NAME="${STANDUP_PUBLISH_CHANNEL_NAME:-<not configured>}"
CHANNEL_ID="${STANDUP_PUBLISH_CHANNEL_ID:-<not configured>}"

echo ""
echo "========================================"
echo "  Standup Archive Backfill"
echo "========================================"
echo ""
echo "  Slack user ID   : ${MY_USER_ID}"
echo "  Publish channel : ${CHANNEL_NAME} (${CHANNEL_ID})"
echo "  Archive dir     : ${ARCHIVE_DIR}"
echo "  Files archived  : ${ARCHIVE_COUNT}"
echo ""
echo "----------------------------------------"
echo "  MCP Slack access required — run inside"
echo "  Claude Code with Slack MCP connected."
echo "----------------------------------------"
echo ""
echo "  Open this project in Claude Code and run:"
echo ""
echo "    /standup-archive"
echo ""
echo "========================================"
echo ""
