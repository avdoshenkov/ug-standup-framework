# Web / Desktop / Mobile Setup

How to use the standup assistant in Claude Web, Mobile, Desktop, Claude Code cloud,
and Claude Code CLI — without any shell tools.

---

## Claude Web / Mobile / Desktop (Claude Projects)

The recommended approach uses the `standup-web` Agent Skill — a self-contained
skill uploaded to your claude.ai account once. It replaces the manual
project-instructions approach from v0.1.

**Full setup guide:** [`../web-skill/README.md`](../web-skill/README.md)

**Quick summary:**

1. `Settings → Features` → enable **Code execution** (once per account).
2. `Customize → Skills → Upload a skill` → upload `../web-skill/standup-web.zip`.
3. Create a Claude project with **Slack + Atlassian** connectors (Calendar optional).
4. Paste the YAML from `project-instructions.template.md` into project **Custom instructions**.
5. Type `собери стендап`.

Minimum YAML fields: `slack_user_id`, `publish_channel_id`, `publish_channel_name`,
`jira_project`, `jira_board_id`, `atlassian_domain`.

> **GitHub:** not available as a web connector. Included automatically in Claude Code.

> **Archive:** the skill writes nothing to disk. Published standups live in Slack.
> Run `/standup-archive` from Claude Code to build a local archive.

---

## Claude Code (cloud or CLI)

The `standup-collect` skill is installed with the plugin and works in Code environments.

**Invoke via natural language** (same triggers) or run `/standup`.

**Config resolution in Code:**
1. If a Claude Project has the config knowledge file → uses it.
2. Otherwise reads `config/local.json` from the workspace via the Read tool.
3. If neither → prompts the user to add a config.

**GitHub activity in Code:**
Included automatically when `gh` CLI is on the path, a GitHub MCP is configured,
or repos are cloned in a cloud routine.
