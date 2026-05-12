# Jira source instructions

Run the shell helper to collect Jira sprint + activity data for `$DATE`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sources/jira/lib/fetch.sh" "$DATE"
```

The helper reads `STANDUP_JIRA_BOARD_ID` and `STANDUP_JIRA_ACCOUNT_ID` from env.

Parse stdout as JSON. Expected shape:
```json
{
  "sprint": {"id": ..., "name": "...", "board_id": ..., "tasks": [...]},
  "events": [
    {"key": "PROJ-123", "summary": "...", "status": "...", "closed_today": false,
     "status_changes": [...], "comments_by_me": [...], "comments_to_me": [...]}
  ]
}
```

Store result under `sources.jira` in `logs/<date>.json`. If `error` field is
present in output, store it as `sources.jira.error` and continue.
