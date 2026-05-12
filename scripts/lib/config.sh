#!/usr/bin/env bash
# config.sh — merge standup config from team-defaults.json + local.json + .env
# Source this file: source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh"
# After sourcing, STANDUP_* env vars are exported.

_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_DATA_DIR="${STANDUP_DATA_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

_DEFAULTS_FILE="${_PLUGIN_ROOT}/config/team-defaults.json"
_LOCAL_FILE="${_DATA_DIR}/config/local.json"
_ENV_FILE="${_DATA_DIR}/.env"

_read_json() {
  local file="$1"
  local path="$2"
  if [[ -f "$file" ]]; then
    jq -r "$path // empty" "$file" 2>/dev/null || true
  fi
}

_read_json_raw() {
  local file="$1"
  local path="$2"
  if [[ -f "$file" ]]; then
    jq -c "$path // empty" "$file" 2>/dev/null || true
  fi
}

# Source .env for local-only secrets (optional — may not exist)
if [[ -f "$_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$_ENV_FILE"
  set +a
fi

# Helper: export var if not already set (env takes highest priority, then local.json, then defaults)
_export_if_empty() {
  local var="$1"
  local val="$2"
  if [[ -z "${!var:-}" && -n "$val" ]]; then
    export "$var"="$val"
  fi
}

# ─── User fields (from local.json .user.*) ────────────────────────────────────
_export_if_empty STANDUP_EMAIL          "$(_read_json "$_LOCAL_FILE" '.user.email')"
_export_if_empty STANDUP_SLACK_USER_ID  "$(_read_json "$_LOCAL_FILE" '.user.slack_user_id')"
_export_if_empty STANDUP_JIRA_ACCOUNT_ID "$(_read_json "$_LOCAL_FILE" '.user.jira_account_id')"

# ─── Team fields (from local.json .team.*, fallback to defaults) ──────────────
_export_if_empty STANDUP_PUBLISH_CHANNEL_ID   "$(_read_json "$_LOCAL_FILE" '.team.publish_channel_id')"
_export_if_empty STANDUP_PUBLISH_CHANNEL_NAME "$(_read_json "$_LOCAL_FILE" '.team.publish_channel_name')"
_export_if_empty STANDUP_SLACK_WORKSPACE_DOMAIN "$(_read_json "$_LOCAL_FILE" '.team.slack_workspace_domain')"
_export_if_empty STANDUP_JIRA_PROJECT         "$(_read_json "$_LOCAL_FILE" '.team.jira_project')"
_export_if_empty STANDUP_JIRA_BOARD_ID        "$(_read_json "$_LOCAL_FILE" '.team.jira_board_id')"
_export_if_empty STANDUP_ATLASSIAN_DOMAIN     "$(_read_json "$_LOCAL_FILE" '.team.atlassian_domain')"
_export_if_empty STANDUP_GH_ORG               "$(_read_json "$_LOCAL_FILE" '.team.gh_org')"
_export_if_empty STANDUP_CONFLUENCE_BASE_URL  "$(_read_json "$_LOCAL_FILE" '.team.confluence_base_url')"

# GH_REPOS: export as JSON array string
if [[ -z "${STANDUP_GH_REPOS:-}" ]]; then
  _gh_repos="$(_read_json_raw "$_LOCAL_FILE" '.team.gh_repos')"
  [[ -n "$_gh_repos" ]] && export STANDUP_GH_REPOS="$_gh_repos"
fi

# Fallback team values from defaults (schema-only in public repo — usually empty)
_export_if_empty STANDUP_PUBLISH_CHANNEL_ID   "$(_read_json "$_DEFAULTS_FILE" '.publish_channel_id')"
_export_if_empty STANDUP_PUBLISH_CHANNEL_NAME "$(_read_json "$_DEFAULTS_FILE" '.publish_channel_name')"
_export_if_empty STANDUP_SLACK_WORKSPACE_DOMAIN "$(_read_json "$_DEFAULTS_FILE" '.slack_workspace_domain')"
_export_if_empty STANDUP_JIRA_PROJECT         "$(_read_json "$_DEFAULTS_FILE" '.jira_project')"
_export_if_empty STANDUP_JIRA_BOARD_ID        "$(_read_json "$_DEFAULTS_FILE" '.jira_board_id')"
_export_if_empty STANDUP_ATLASSIAN_DOMAIN     "$(_read_json "$_DEFAULTS_FILE" '.atlassian_domain')"
_export_if_empty STANDUP_GH_ORG               "$(_read_json "$_DEFAULTS_FILE" '.gh_org')"
_export_if_empty STANDUP_CONFLUENCE_BASE_URL  "$(_read_json "$_DEFAULTS_FILE" '.confluence_base_url')"

# ─── Personal fields (from local.json .personal.*) ────────────────────────────
if [[ -z "${STANDUP_INPUT_SLACK_CHANNELS:-}" ]]; then
  _channels="$(_read_json_raw "$_LOCAL_FILE" '.personal.input_slack_channels')"
  [[ -n "$_channels" ]] && export STANDUP_INPUT_SLACK_CHANNELS="$_channels"
fi

# ─── Enabled sources ─────────────────────────────────────────────────────────
if [[ -z "${STANDUP_ENABLED_SOURCES:-}" ]]; then
  _sources="$(_read_json_raw "$_LOCAL_FILE" '.enabled_sources')"
  if [[ -z "$_sources" ]]; then
    _sources="$(_read_json_raw "$_DEFAULTS_FILE" '.enabled_sources')"
  fi
  [[ -n "$_sources" ]] && export STANDUP_ENABLED_SOURCES="$_sources"
fi

# ─── Data dir ─────────────────────────────────────────────────────────────────
export STANDUP_DATA_DIR="$_DATA_DIR"
