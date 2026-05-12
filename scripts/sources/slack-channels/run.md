# Slack-channels source instructions (stub — v0.1.0)

This source is a stub in v0.1.0. Record result as:

```json
{"events": [], "skipped": "stub — not implemented in v0.1.0"}
```

To implement: replace this directory under `${STANDUP_DATA_DIR}/sources/slack-channels/`
with a working version following the MCP-kind source contract.

When implemented, this source should:
1. Call `mcp__claude_ai_Slack__slack_search_public_and_private` for each channel
   in `STANDUP_INPUT_SLACK_CHANNELS`.
2. Collect messages from the user and mentions of the user since `$DATE`.
3. Return `{"events": [...]}` with relevant Slack activity.
