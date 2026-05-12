# Slack-self source instructions

This is an MCP-kind source. Execute these steps directly in the orchestrator skill
(model context) — do NOT call a bash subprocess.

1. Call MCP `mcp__claude_ai_Slack__slack_search_public_and_private` with:
   - query: `from:${STANDUP_SLACK_USER_ID} in:<channel-name> after:${DATE}`
   - Use `STANDUP_PUBLISH_CHANNEL_NAME` for the channel name in the query.

2. Collect returned messages. For each message, extract:
   - `ts` — Slack timestamp
   - `text` — message body
   - `channel` — channel ID (should match `STANDUP_PUBLISH_CHANNEL_ID`)

3. Build the events array:
   ```json
   {
     "events": [
       {"ts": "...", "text": "...", "channel": "...", "at": "<ISO from ts>"}
     ]
   }
   ```

4. Store result under `sources.slack-self` in `logs/<date>.json`.
   If the MCP call fails, store `{"events":[], "error":"<message>"}` and continue.
