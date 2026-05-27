# Web / Desktop / Mobile Setup

How to use the standup assistant in Claude Web, Mobile, Desktop, Claude Code cloud,
and Claude Code CLI — without any shell tools.

---

## Claude Web / Mobile / Desktop (Claude Projects)

### Step 1 — Create a Claude project

Open [claude.ai](https://claude.ai) → Projects → New project.

### Step 2 — Connect MCP integrations

In project settings, enable connectors:

| Integration | Required | Used for |
|---|---|---|
| Slack | ✅ Yes | preview/publish, activity search |
| Atlassian Rovo | ✅ Yes | Jira sprint and activity |
| Google Calendar | Optional | meeting context |

> **Note:** GitHub is not available as an autonomous connector in Web/Mobile/Desktop
> project chat. GitHub activity (PRs, commits) is included automatically when running
> from Claude Code where `gh` or a GitHub MCP is reachable.

### Step 3 — Add project instructions

Copy the contents of [`project-instructions.template.md`](./project-instructions.template.md)
into the project's **Custom instructions** field.

### Step 4 — Add config knowledge file

Copy [`config.template.md`](./config.template.md), fill in your values, and upload
to the project as a knowledge file (name it `config.md`).

Minimum required fields:
- `slack_user_id`, `publish_channel_id`, `publish_channel_name`
- `jira_project`, `jira_board_id`, `atlassian_domain`

### Step 5 — Add style knowledge file (optional)

Copy [`style.template.md`](./style.template.md), fill in your language and style
preferences, and upload as a knowledge file (name it `style.md`).
If skipped, the assistant uses generic defaults.

### Step 6 — Collect your standup

In the project chat, type any of:
- `собери стендап`
- `evening standup`
- `подготовь вечернее письмо`

The assistant will fetch your Jira, Calendar, and Slack activity,
draft the message, send you a self-DM preview, and ask whether to publish.

> **Archive in Web mode:** the daily skill writes nothing to disk. Your published
> standups live in Slack. To build a local archive, set up Claude Code with the
> plugin and run `/standup-archive` periodically.

---

## Claude Code (cloud or CLI)

The `standup-collect` skill is installed with the plugin and works in Code environments.

**Invoke via natural language** (same triggers as above) or run `/standup`.

**Config resolution in Code:**
1. If a Claude Project is associated and has the config knowledge file → uses it.
2. Otherwise reads `config/local.json` from the workspace via the Read tool.
3. If neither → prompts the user to add a config.

**GitHub activity in Code:**
Included automatically when `gh` CLI is on the path, a GitHub MCP is configured,
or repos are cloned in a cloud routine. Not available in plain Web/Mobile/Desktop.
