# ug-standup

Claude plugin for automated evening standup collection and publishing.

Collects activity from Jira, Slack, GitHub (optional), Google Calendar (optional),
and Confluence (optional), then drafts and publishes your team's evening standup message.

**One skill, any surface** — works in Claude Web, Mobile, Desktop, Claude Code cloud,
and Claude Code CLI. No shell tools required. All data via MCP connectors.

---

## Quick start

### Claude Web / Mobile / Desktop (Claude Projects)

1. Create a Claude Project.
2. Connect MCP integrations (Project settings → Integrations):
   - **Slack** — required
   - **Atlassian Rovo** — required (Jira sprint + activity)
   - **Google Calendar** — optional (meeting context)
3. Add project instructions — paste the contents of
   [`web-template/project-instructions.template.md`](./web-template/project-instructions.template.md).
4. Upload a filled config file — copy
   [`web-template/config.template.md`](./web-template/config.template.md),
   fill in your values, upload as a knowledge file named `config.md`.
5. Optionally upload a style file — copy
   [`web-template/style.template.md`](./web-template/style.template.md),
   fill in your phrasing preferences, upload as `style.md`.
6. Type `"собери стендап"` or `"evening standup"`.

### Claude Code (CLI or Desktop)

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

### New user (Claude Code)

From any Claude Code workspace with this plugin installed:

```
/standup-init
```

Interactive prompts collect your config and create a private data repo.

---

## Commands

| Command | Description |
|---|---|
| `/standup` | Collect activity + draft standup (all Claude surfaces) |
| `/standup-archive` | Pull standup messages from Slack into `archive/` (run weekly) |
| `/standup-init` | Bootstrap a new data repo (Claude Code only) |

Natural language triggers (Web / Mobile / Desktop): `"собери стендап"`,
`"evening standup"`, `"подготовь вечернее письмо"`, `"what did I do today"`.

---

## Config

For Claude Code, config lives in your private data repo at `config/local.json`.
For Web/Mobile/Desktop, config is a knowledge file (`config.md`) in your Claude Project.

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
    "gh_repos": ["your-org/frontend", "your-org/backend"]
  },
  "personal": {
    "input_slack_channels": []
  },
  "confluence": {
    "enabled": false
  }
}
```

---

## Sources

| Source | Available | Description |
|---|---|---|
| Jira | all surfaces | Sprint + activity via Atlassian MCP |
| Slack | all surfaces | Your messages + DMs via Slack MCP |
| Google Calendar | all surfaces | Meetings via Google Calendar MCP (optional) |
| GitHub | Claude Code only | PRs + commits via `gh` CLI or GitHub MCP (optional) |
| Confluence | Claude Code + Desktop | Pages/comments via Atlassian/Rovo or Confluence MCP (optional, opt-in) |

> **Why no GitHub in Web/Mobile?** The claude.ai project connector list has no GitHub
> tool for autonomous chat use (only manual file-attach and read-only repo sync). GitHub
> activity is automatically included when running from Claude Code where `gh` or a
> GitHub MCP is reachable.

---

## Archive

The daily standup skill writes nothing to disk. To maintain a searchable offline
archive, run `/standup-archive` periodically (weekly recommended):

```
/standup-archive
```

This pulls your standup messages from Slack into `archive/YYYY-MM-DD.md`. Existing
files are never overwritten — safe to re-run.

---

## Automate via Claude Code Routines

You can automate the daily standup draft using [Claude Code Routines](https://claude.ai/code)
(Settings → Routines → New routine).

### Daily compose routine

| Setting | Value |
|---|---|
| Trigger | Schedule — weekdays at your EOD time (e.g. `0 18 * * 1-5`) |
| **Repo / workspace** | Your **data repo** (e.g. `personal-muse-assistant`) — carries plugin enable + `config/local.json` |
| Connectors | Atlassian Rovo, Slack, Google Calendar |
| Instructions | `собери стендап` |

The skill is loaded from the `ug-standup` plugin enabled in the data repo's
`.claude/settings.json`; config is read from `config/local.json` in the same repo.
Do **not** paste the skill as chat instructions — it ships via the plugin.

**GitHub activity (optional):** add a GitHub connector to the routine. The skill reads
`team.gh_repos` from `config/local.json` and queries those repos for PRs and commits.
Without a GitHub connector the step is skipped and the letter is built from
Jira + Slack + Calendar.

You do **not** need to attach your code repos as the workspace — the data repo is the
only workspace. Repo names for GitHub queries live in `config/local.json`.

> **Important:** routines run unattended and connectors grant write access without
> per-action confirmation. Do **not** auto-publish to the team channel — the skill
> will send a self-DM preview and wait. Review and publish manually.
> Only set auto-publish if you are confident in fully hands-off operation.

### Weekly archive routine

| Setting | Value |
|---|---|
| Trigger | Schedule — weekly (e.g. Sundays) |
| Repo / workspace | Your data repo |
| Connectors | Slack |
| Instructions | `выгрузи стендапы из Slack` |

---

## Confluence (optional)

To include Confluence activity in the standup:

1. Set `confluence.enabled: true` in your config.
2. Connect the right tool:
   - **Cloud Confluence** — already available via the Atlassian/Rovo connector.
   - **Self-hosted Confluence** — requires the
     [mcp-atlassian](https://github.com/sooperset/mcp-atlassian) server.

### Self-hosted Confluence MCP setup

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

---

## Prerequisites

- Claude Code with Slack MCP connected
- Atlassian/Rovo connector (or mcp-atlassian for self-hosted)
- `gh` (GitHub CLI) — optional, for GitHub activity in Claude Code CLI
- `jq` — required only for `/standup-init`

## License

MIT
