#!/usr/bin/env bash
set -euo pipefail

# init-data-repo.sh — bootstrap a new standup data repository
# Called by /standup-init command. Interactive prompts collect per-user + team config.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

command -v jq  >/dev/null 2>&1 || { echo >&2 "[init] jq required"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "[init] git required"; exit 1; }
command -v gh  >/dev/null 2>&1 || { echo >&2 "[init] gh CLI required (brew install gh)"; exit 1; }

prompt() {
  local var="$1"
  local label="$2"
  local default="${3:-}"
  local value=""
  if [[ -n "$default" ]]; then
    read -rp "${label} [${default}]: " value
    value="${value:-$default}"
  else
    while [[ -z "$value" ]]; do
      read -rp "${label}: " value
    done
  fi
  printf -v "$var" '%s' "$value"
}

echo ""
echo "================================================"
echo "  /standup-init — Standup Data Repo Bootstrap"
echo "================================================"
echo ""
echo "This will create a private GitHub repo for your standup logs."
echo "Press Ctrl-C at any time to abort."
echo ""

GH_HANDLE="$(gh api user --jq .login 2>/dev/null || echo "")"
DEFAULT_REPO_NAME="${GH_HANDLE:+${GH_HANDLE}-standup-log}"

prompt REPO_NAME    "Data repo name"               "${DEFAULT_REPO_NAME}"
prompt USER_EMAIL   "Your work email"
prompt SLACK_USER_ID "Your Slack user ID (e.g. U01ABC)"
prompt JIRA_ACCOUNT_ID "Your Jira account ID"
prompt PUBLISH_CHANNEL_ID   "Standup Slack channel ID (e.g. C01ABC)"
prompt PUBLISH_CHANNEL_NAME "Standup Slack channel name (e.g. #team-standups)"
prompt SLACK_WORKSPACE_DOMAIN "Slack workspace domain (e.g. company.slack.com)"
prompt JIRA_PROJECT "Jira project key (e.g. ABC)"
prompt JIRA_BOARD_ID "Jira board ID (e.g. 123)"
prompt ATLASSIAN_DOMAIN "Atlassian domain (e.g. company.atlassian.net)"
prompt GH_ORG       "GitHub org (e.g. my-org)"
prompt GH_REPOS     "GitHub repos to track (comma-separated, e.g. my-org/frontend,my-org/backend)"
prompt CONFLUENCE_BASE_URL "Confluence base URL (leave blank if unused)"

LOCAL_DIR="${HOME}/Documents/${REPO_NAME}"

echo ""
echo "Creating private repo ${REPO_NAME} and cloning to ${LOCAL_DIR}..."
gh repo create "${REPO_NAME}" --private --clone --gitignore Node -y 2>/dev/null \
  || { echo >&2 "[init] gh repo create failed"; exit 1; }
mv "$REPO_NAME" "$LOCAL_DIR" 2>/dev/null || true
cd "$LOCAL_DIR"

mkdir -p config archive .claude

# Build gh_repos JSON array
REPOS_JSON="$(echo "$GH_REPOS" | jq -Rc 'split(",") | map(ltrimstr(" ") | rtrimstr(" ")) | map(select(. != ""))')"

# Write config/local.json
cat > config/local.json <<EOF
{
  "user": {
    "email": "${USER_EMAIL}",
    "slack_user_id": "${SLACK_USER_ID}",
    "jira_account_id": "${JIRA_ACCOUNT_ID}"
  },
  "team": {
    "publish_channel_id": "${PUBLISH_CHANNEL_ID}",
    "publish_channel_name": "${PUBLISH_CHANNEL_NAME}",
    "slack_workspace_domain": "${SLACK_WORKSPACE_DOMAIN}",
    "jira_project": "${JIRA_PROJECT}",
    "jira_board_id": ${JIRA_BOARD_ID},
    "atlassian_domain": "${ATLASSIAN_DOMAIN}",
    "gh_org": "${GH_ORG}",
    "gh_repos": ${REPOS_JSON},
    "confluence_base_url": "${CONFLUENCE_BASE_URL}"
  },
  "personal": {
    "input_slack_channels": []
  },
  "confluence": {
    "enabled": false
  }
}
EOF

# Copy template files
cp "${PLUGIN_ROOT}/templates/gitignore.template" .gitignore
cp "${PLUGIN_ROOT}/templates/settings.json.template" .claude/settings.json
cp "${PLUGIN_ROOT}/templates/readme.template.md" README.md
cp "${PLUGIN_ROOT}/templates/style.md.template" config/style.md

# Initial commit
git add .
git commit -m "init standup log"
git push -u origin main

echo ""
echo "================================================"
echo "  Done! Data repo created at: ${LOCAL_DIR}"
echo "  GitHub: https://github.com/${GH_HANDLE}/${REPO_NAME}"
echo ""
echo "  Next: open ${LOCAL_DIR} in Claude Code and run /standup"
echo "================================================"
echo ""
