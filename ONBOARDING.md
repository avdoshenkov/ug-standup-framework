# Standup Assistant — Onboarding

Two setup paths. Pick one based on your surface.

| | Claude Code (CLI / Desktop) | claude.ai (Web / Mobile / Desktop) |
|---|---|---|
| GitHub activity | yes (via `gh` CLI or GitHub MCP) | no |
| Local archive | yes (`archive/YYYY-MM-DD.md`) | no (Slack only) |
| Routines / automation | yes | no |
| Install | plugin via marketplace | upload ZIP once |

---

## Part 0 — Common: gather config values

You need these regardless of surface. Find them before starting.

| Value | Where to find |
|---|---|
| `email` | your work email |
| `slack_user_id` | Slack → profile → `⋯` → Copy member ID |
| `jira_account_id` | Jira → profile URL → last UUID segment (Code only) |
| `publish_channel_id` | Slack → right-click standup channel → View channel details → ID at the bottom |
| `publish_channel_name` | e.g. `#owl-ugproduct` |
| `jira_project` | Jira project key, e.g. `UGP` |
| `jira_board_id` | from board URL: `/jira/software/boards/123` |
| `atlassian_domain` | e.g. `company.atlassian.net` |
| `gh_org` / `gh_repos` | Code only — your GitHub org and repo list |

---

## Part A — Claude Code (CLI or Desktop)

### 1. Enable the plugin (no clone needed)

Add to `~/.claude/settings.json` (global) or your data repo's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "ug-standup@ug-standup-framework": true
  },
  "extraKnownMarketplaces": {
    "ug-standup-framework": {
      "source": {
        "source": "github",
        "repo": "avdoshenkov/ug-standup-framework"
      }
    }
  }
}
```

### 2. Create your data repo

Run `/standup-init` from any Claude Code workspace with the plugin enabled.

Interactive prompts collect your config values and:
- create a private GitHub repo
- scaffold `config/local.json` and `archive/`
- generate `.claude/settings.json` with the plugin enabled
- commit and push

Requirements: `jq`, `git`, `gh` (authenticated).

*If you already have a data repo:* fill `config/local.json` manually using the schema
in the main [README](./README.md#config).

### 3. Run

Open your data repo in Claude Code, then:

```
/standup
```

Or say: `"собери стендап"` / `"evening standup"`.

**Weekly archive:**
```
/standup-archive
```

**GitHub activity** is included automatically when `gh` is on PATH or a GitHub MCP is configured.

---

## Part B — claude.ai (Web / Mobile / Desktop)

### 1. Enable code execution

`claude.ai → Settings → Features` → turn on **Code execution**.

One-time per account. Skills require this toggle.

### 2. Upload the skill

`Customize → Skills → + Create skill → Upload a skill`

Upload: [`web-skill/standup-web.zip`](./web-skill/standup-web.zip)

Account-global — upload once, works in all projects.

### 3. Create a project and connect integrations

Projects → New project. In project settings enable:

| Integration | Required |
|---|---|
| Slack | yes |
| Atlassian | yes |
| Google Calendar | optional |

### 4. Add config to project instructions

Copy [`web-skill/config.template.md`](./web-skill/config.template.md),
fill in your values (from Part 0), and paste into the project's **Custom instructions** field.

Optionally upload [`web-skill/style.template.md`](./web-skill/style.template.md)
(filled) as a knowledge file named `style.md`.

### 5. Run

In the project chat:
```
собери стендап
```

The skill fetches Jira + Calendar + Slack, drafts the message, sends a self-DM preview,
then asks: publish / edit / send manually / not today.

No GitHub source. No local archive — published standups live in Slack.
