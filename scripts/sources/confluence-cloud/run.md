# Confluence Cloud source instructions (stub — v0.1.0)

This source is a stub in v0.1.0. Record result as:

```json
{"events": [], "skipped": "stub — not implemented in v0.1.0"}
```

To implement: replace this directory under `${STANDUP_DATA_DIR}/sources/confluence-cloud/`
with a working version following the MCP-kind source contract.

When implemented, this source should:
1. Call `mcp__claude_ai_Atlassian__searchConfluenceUsingCql` to find pages created
   or modified by the current user since `$DATE`.
2. Return `{"events": [...]}` with page titles, URLs, and change summaries.
