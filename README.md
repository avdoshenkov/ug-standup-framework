# ug-standup

Claude Code plugin for automated evening standup collection and publishing.

Collects activity from Jira, GitHub, local git, and Slack, then drafts and
publishes your team's evening standup message.

## Quick start (existing user)

1. Add to your data repo's `.claude/settings.json`:
   ```json
   {
     "enabledPlugins": [
       {
         "name": "ug-standup",
         "source": "github:avdoshenkov/ug-standup-framework",
         "version": "0.1.0"
       }
     ]
   }
   ```
2. Ensure `config/local.json` is populated (see [Config](#config)).
3. Open your data repo in Claude Code. Run `/standup`.

## Onboarding (new user)

From any Claude Code workspace with this plugin installed:

```
/standup-init
```

Interactive prompts will collect your config and create a private data repo.

## Commands

| Command | Description |
|---|---|
| `/standup` | Collect activity + draft standup (local mode, includes git commits) |
| `/standup-cloud` | Same but cloud-mode — no local git repos needed |
| `/standup-archive` | Backfill historical standup messages from Slack |
| `/standup-init` | Bootstrap a new data repo for a new user |

## Config

Config lives in your private data repo at `config/local.json` (committed).
Secrets and local paths go in `.env` (gitignored).

### config/local.json

```json
{
  "user": {
    "email": "you@example.com",
    "slack_user_id": "UXXXXXXXX",
    "jira_account_id": "..."
  },
  "team": {
    "publish_channel_id": "CXXXXXXXX",
    "publish_channel_name": "#your-standup-channel",
    "slack_workspace_domain": "yourcompany.slack.com",
    "jira_project": "PROJ",
    "jira_board_id": 123,
    "atlassian_domain": "yourcompany.atlassian.net",
    "gh_org": "your-org",
    "gh_repos": ["your-org/frontend", "your-org/backend"],
    "confluence_base_url": ""
  },
  "personal": {
    "input_slack_channels": []
  },
  "enabled_sources": ["jira", "github", "git", "slack-self"]
}
```

### .env (gitignored, local-only)

```bash
# Only needed if 'git' source enabled
STANDUP_LOCAL_REPOS=/path/to/repo1:/path/to/repo2

# Only needed if 'confluence-self-hosted' source enabled
STANDUP_CONFLUENCE_TOKEN=
```

## Sources

| Name | Kind | Available | Description |
|---|---|---|---|
| `jira` | shell | local + cloud | Jira issues/comments via `acli` |
| `github` | shell | local + cloud | Commits and PRs via `gh` |
| `git` | shell | local only | Local git commits across configured repos |
| `slack-self` | mcp | local + cloud | Your messages in the standup channel |
| `slack-channels` | mcp | local + cloud | **stub** — activity in personal channels |
| `confluence-cloud` | mcp | local + cloud | **stub** — cloud Confluence pages |
| `confluence-self-hosted` | mcp | local only | **stub** — self-hosted Confluence |

### Custom sources

Add `sources/<name>/` to your data repo with `source.json` + `run.md` (+ `lib/fetch.sh` for shell kind).
Add the source name to `enabled_sources` in `config/local.json`. No framework change required.

### Self-hosted Confluence MCP setup

Requires the [mcp-atlassian](https://github.com/sooperset/mcp-atlassian) server.
Prerequisites: Python 3.10–3.13 + `uv` (`pip install uv`).

Add to `~/.claude.json` or `.claude/mcp-servers.json`:

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

## Prerequisites

- Claude Code with Slack MCP connected
- `acli` (Atlassian CLI) — for local Jira collection
- `gh` (GitHub CLI) — for GitHub collection
- `jq` — for JSON processing

## License

MIT
