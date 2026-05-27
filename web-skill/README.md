# standup-web — Claude.ai Skill

Self-contained standup skill for Claude Web, Desktop, and Mobile.
No shell, no filesystem, no subagents. All data via MCP connectors.

---

## Setup (~5 min)

### 1. Enable code execution

`claude.ai → Settings → Features` → turn on **Code execution**.

Required once per account — skills need this toggle on.

### 2. Install the skill

**Muse org members:** go to `Customize → Skills → Organization skills → standup-web → Install`
(direct install link available from your team — ask in Slack or check the Confluence doc)

Updates are automatic — no reinstall needed when the skill is updated.

**Outside the org / self-hosting:** `Customize → Skills → + Create skill → Upload a skill` → `standup-web.zip`.
Skill is account-global. Upload once; works in all projects.

### 3. Create a Claude project and connect integrations

Projects → New project. In project settings enable:

| Integration | Required |
|---|---|
| Slack | yes |
| Atlassian | yes |
| Google Calendar | optional |

GitHub is not available as a web connector — GitHub activity is included automatically in Claude Code.

### 4. Add config to project instructions

Copy the YAML block from `config.template.md` (or use your personal `test-config.md`),
fill in your values, and paste into the project's **Custom instructions** field.

Minimum required fields: `slack_user_id`, `publish_channel_id`, `jira_project`, `atlassian_domain`.

### 5. Collect your standup

In the project chat, type any of:
- `собери стендап`
- `evening standup`
- `подготовь вечернее письмо`

The skill fetches Jira + Calendar + Slack activity, drafts the message,
sends a self-DM preview, then asks: publish / edit / send manually / not today.

---

## Updating the skill

If `standup-web/SKILL.md` changes, rebuild the zip:

```bash
./scripts/build-web-skill.sh
```

Then re-upload `standup-web.zip` in Customize → Skills.

---

## Files

```
web-skill/
  standup-web/
    SKILL.md          canonical skill source
  standup-web.zip     upload this to claude.ai
  config.template.md  YAML config template to paste into project instructions
  README.md           this file
```
