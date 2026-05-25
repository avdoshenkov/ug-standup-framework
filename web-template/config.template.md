# Standup Config

Personal and team settings for the standup assistant.
Fill in your values below. This file is loaded as a project knowledge file in Claude Web/Mobile/Desktop, or kept in `config/local.json` in your data-repo for Claude Code.

---

```yaml
# --- Required ---

email: you@company.com                  # your work email
slack_user_id: UXXXXXXXX               # Slack user ID (Settings → Profile → copy member ID)
publish_channel_id: CXXXXXXXX          # ID of the channel where standup is posted
publish_channel_name: standup-backend  # human-readable name (for display)
jira_project: PROJ                     # Jira project key (e.g. MYAPP)
jira_board_id: 42                      # Jira board ID (from board URL)
atlassian_domain: company.atlassian.net

# --- GitHub (recommended) ---

gh_org: my-org
gh_repos:
  - my-org/frontend
  - my-org/backend

# --- Optional: Google Calendar ---

calendar_id: primary    # or the specific calendar ID from Google Calendar settings

# --- Optional: state + archive via GitHub ---
# If set, state.json and archive/*.md are stored in this private repo.
# Great for cross-device sync (Web ↔ Code CLI ↔ Mobile).

data_repo: owner/my-standup-log    # owner/repo on GitHub
github_branch: main

# --- Optional: Slack channel filter ---
# If empty (default), global search is used (from:me / to:me).
# Set to restrict search to specific channels for better signal/noise.

input_slack_channels: []
# input_slack_channels:
#   - standup-backend
#   - dev-team
```
