# Confluence Self-Hosted source instructions (stub — v0.1.0)

This source is a stub in v0.1.0. Record result as:

```json
{"events": [], "skipped": "stub — not implemented in v0.1.0"}
```

To implement: replace this directory under `${STANDUP_DATA_DIR}/sources/confluence-self-hosted/`
with a working version following the MCP-kind source contract.

**Prerequisites (local only):**
This source requires the `mcp-atlassian` third-party MCP server (sooperset).
See framework README.md for setup instructions. Requires Python 3.10–3.13 + `uv`.

Example MCP server config (~/.claude.json or .claude/mcp-servers.json):
```jsonc
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "/Users/<you>/.local/bin/uvx",
      "args": ["--python=3.12", "mcp-atlassian"],
      "env": {
        "JIRA_URL": "<your jira url>",
        "JIRA_USERNAME": "<your email>",
        "JIRA_API_TOKEN": "",
        "CONFLUENCE_URL": "<your confluence base url>",
        "CONFLUENCE_PERSONAL_TOKEN": ""
      }
    }
  }
}
```

When implemented, this source should use the `mcp-atlassian` server's tools to
search for Confluence pages created or edited by the current user since `$DATE`.
