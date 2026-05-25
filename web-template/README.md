# Web Mode Setup

How to use the standup assistant in Claude Web, Mobile, Desktop chat, Claude Code cloud, and Claude Code CLI — without any shell tools.

---

## Claude Web / Mobile / Desktop (Claude Projects)

### Step 1 — Create a Claude project

Open [claude.ai](https://claude.ai) → Projects → New project.

### Step 2 — Connect MCP integrations

In project settings, enable connectors:

| Integration | Required | Used for |
|---|---|---|
| Slack | ✅ Yes | preview/publish, activity search |
| Atlassian | ✅ Yes | Jira sprint and activity |
| GitHub | Recommended | PRs, commits, state + archive storage |
| Google Calendar | Recommended | meeting context |

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

The assistant will fetch your Jira, GitHub, Calendar, and Slack activity,
draft the message, send you a self-DM preview, and ask whether to publish.

---

## Optional: cross-device sync via GitHub data-repo

If you use standup both from the browser and from Claude Code CLI, add a
`data_repo: owner/repo` line to your config. The assistant will read/write
`config/state.json` and `archive/*.md` in that private GitHub repo via GitHub MCP,
so sprint cache and last standup context are always in sync.

---

## Claude Code cloud and CLI

The `standup-collect-web` skill is installed with the plugin and works in Code environments too.

**Invoke via natural language** (same triggers as above) — the skill activates from the
plugin's skill registry.

**Config resolution in Code:**
1. If a Claude Project is associated and has the config knowledge file → uses it.
2. Otherwise, if a data-repo is open as the workspace → reads `config/local.json` from filesystem.
3. If neither → prompts the user to add a config.

**State and archive in Code:**
- If `data_repo` is set → writes via GitHub MCP (same as Web).
- If data-repo is open as workspace → writes to filesystem and git-commits locally.

---

## Mode comparison

| Feature | Local `/standup` | Cloud `/standup-cloud` | Web mode |
|---|---|---|---|
| Works in Claude Web/Mobile | ❌ | ❌ | ✅ |
| Local git commits | ✅ | ❌ | ❌ |
| Jira | shell (`acli`) | Atlassian MCP | Atlassian MCP |
| GitHub | shell (`gh`) | shell (`gh`) | GitHub MCP |
| Google Calendar | ❌ | ❌ | ✅ (optional) |
| Requires shell tools | ✅ | ✅ | ❌ |
| State persistence | Local fs | Local fs | GitHub MCP or local fs |
| Archive | Local fs | Local fs | GitHub MCP or local fs |
