# Standup config

Paste this YAML block into the Claude project **Custom instructions** field.
The `standup-web` skill reads it automatically (Step 0).

```yaml
# --- Required ---

email: you@company.com                   # your work email
slack_user_id: UXXXXXXXX                # Slack: Settings → Profile → ⋯ → Copy member ID
publish_channel_id: CXXXXXXXX           # Slack: right-click channel → View channel details → ID at bottom
publish_channel_name: "#team-standup"   # must be quoted — # is a YAML comment character
jira_project: PROJ                      # Jira project key (e.g. UGP)
jira_board_id: 123                      # from board URL: /jira/software/boards/123
atlassian_domain: company.atlassian.net

# --- Optional ---

calendar_id: primary    # or specific calendar ID from Google Calendar settings
input_slack_channels: []               # default: global search. Restrict to specific channels if needed
confluence:
  enabled: false
```
