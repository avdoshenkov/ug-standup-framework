# Standup config

Paste this YAML block into the project's Custom instructions field.
The `standup-web` skill reads it automatically on each run (Step 0).

```yaml
email: you@example.com
slack_user_id: UXXXXXXXX
publish_channel_id: CXXXXXXXX
publish_channel_name: "#your-standup-channel"   # quotes required — # is YAML comment char
jira_project: PROJ
jira_board_id: 123
atlassian_domain: your-org.atlassian.net
calendar_id: primary          # optional
input_slack_channels: []      # optional — default: global search
confluence:
  enabled: false              # optional
```

> Required connectors for this project: **Slack**, **Atlassian**.
> Optional: Google Calendar.
> The `standup-web` skill must be uploaded via Customize → Skills — see `web-skill/README.md`.
