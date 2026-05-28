---
name: standup-collect
description: Universal MCP-only evening standup collection — works in Claude Web, Mobile, Desktop, Claude Code cloud, and Claude Code CLI. No bash required. All data via Slack MCP, Atlassian MCP, GitHub MCP (optional), Google Calendar MCP (optional), and Confluence (optional). Triggered by "собери стендап", "evening standup", "подготовь вечернее письмо", "what did I do today".
---

# Standup Collect — Universal

Collect today's activity and produce a formatted Slack standup message. Works in any
Claude environment: Web, Mobile, Desktop, Claude Code cloud, Claude Code CLI.
No bash required. No local filesystem required. All data via MCP connectors.

Nothing is written to disk. No state file maintained. Each run is self-contained.

---

## Step 0 — Load config

Load team config from the **first available source**, in priority order:

### Source A — Project knowledge file or project instructions (primary)

Scan the conversation context (system message, project instructions, knowledge files)
for a YAML block with standup config. Example shape:

```yaml
email: you@example.com
slack_user_id: UXXXXXXXX
publish_channel_id: CXXXXXXXX
publish_channel_name: standup-team
jira_project: PROJ
jira_board_id: 123
atlassian_domain: company.atlassian.net
gh_org: my-org
gh_repos:
  - my-org/frontend
  - my-org/backend
calendar_id: primary          # optional — Google Calendar ID
input_slack_channels: []      # optional — default: global search
confluence:
  enabled: false              # optional — set true to include Confluence activity
```

If found and contains all required fields, extract values. Proceed to Step 1.

### Source B — Filesystem (Claude Code only)

If Source A is not found AND the Read tool is available, try reading
`config/local.json` from the current workspace. Map fields:

```
user.email                → email
user.slack_user_id        → slack_user_id
user.jira_account_id      → jira_account_id
team.publish_channel_id   → publish_channel_id
team.publish_channel_name → publish_channel_name
team.jira_project         → jira_project
team.jira_board_id        → jira_board_id
team.atlassian_domain     → atlassian_domain
team.gh_org               → gh_org
team.gh_repos             → gh_repos
personal.input_slack_channels → input_slack_channels (default [])
confluence                → confluence (default {enabled: false})
```

If found, proceed to Step 1.

### Source C — Fail gracefully

If neither source is found, stop and tell the user:

> ⚠️ Конфиг не найден. Добавь YAML-блок с настройками в project instructions или knowledge file проекта. Шаблон: `web-skill/config.template.md` в репозитории плагина.

Do NOT proceed without at least: `slack_user_id`, `publish_channel_id`, `jira_project`, `atlassian_domain`.

---

## Step 1 — Resolve `since`

Compute the window start from the last posted standup in the channel:

1. Run MCP `slack_search_public_and_private` with query
   `from:me in:{publish_channel_name}`, scoped to last 7 days.
2. If a result is found, take the most recent post's timestamp as `SINCE`.
3. If no result (first run, or channel name unknown):
   - Today is Monday → `SINCE` = last Friday at 00:00 local time.
   - Otherwise → `SINCE` = yesterday at 00:00 local time.

Store:
- `SINCE` — full ISO-8601 with timezone (e.g., `2026-04-28T00:00:00+03:00`)
- `SINCE_DATE` — date only (`YYYY-MM-DD`, for JQL filters)
- `LAST_STANDUP_TEXT` — full text of the most recent standup (if found), for use in Step 7.

---

## Step 2 — Resolve current sprint

Call `searchJiraIssuesUsingJql` with JQL:
`assignee = currentUser() AND sprint in openSprints()`

Inspect response to find active sprint id and name. Build sprint task list:
`tasks: [{key, summary, status, url}, ...]`

If the MCP call fails or returns no open sprint, set sprint name to `""` and task
list to `[]`. Do not stop — continue with empty sprint context.

---

## Step 3 — Fetch Jira activity

1. Call MCP `searchJiraIssuesUsingJql` with JQL:
   `assignee = currentUser() AND updated >= '${SINCE_DATE}'`
2. For each returned issue key:
   - Call MCP `getJiraIssue` to retrieve changelog and comments.
   - Build activity entry:
     ```
     {
       key, summary, url, status,
       status_changes: [{from, to, at}, ...]      # filtered: created >= SINCE
       comments_by_me: [{at, body}, ...]
       comments_to_me: [{at, author, body}, ...]
     }
     ```
3. If `jira_account_id` is missing from config, leave comment arrays empty.

---

## Step 4 — Fetch GitHub activity (optional)

**If a GitHub tool is available** (check by attempting a minimal call — `gh` CLI in
local Claude Code, or a configured GitHub MCP / cloud connector):

For each repo in `gh_repos`:

1. **PRs authored by me** — search for PRs updated since `SINCE_DATE`.
   Collect: `{number, title, state, url, merged_at, updated_at, base_branch}`

2. **Commits by me** — list commits in repo since `SINCE` for authenticated user.
   Collect: `{sha, message, url, date, branch}`

3. **PR review requests** — PRs where I'm requested reviewer, updated since `SINCE`.
   Collect: `{number, title, url, author}`

Build GitHub events:
```json
{
  "prs": [...],
  "commits": [...],
  "review_requests": [...]
}
```

**If no GitHub tool is available:**

Set `github_activity: null`. Do not fail — continue.

---

## Step 5 — Fetch Calendar events (optional)

**Attempt calendar fetch** — Google Calendar tools are often deferred in Claude Code and may not appear in the active tool set on the first check:

1. Look for `list_events` or any Google Calendar tool in the active tool set.
2. If not found: attempt to load it (e.g. via `ToolSearch` with query `"google calendar list_events"` or `"select:mcp__claude_ai_Google_Calendar__list_events"`) and retry once.
3. Call the tool:
   - Calendar: `calendar_id` from config (default: `primary`)
   - Time range: from `SINCE` to `now + 1 day`
   - Filter: attendee or organizer; exclude declined.

Collect events:
```json
[
  {
    "summary": "Sprint planning",
    "start": "2026-05-22T10:00:00",
    "end": "2026-05-22T11:00:00",
    "status": "accepted"
  }
]
```

**Only if the load attempt fails or the tool genuinely does not exist:**

Set `calendar_events: []`. Do not fail.

---

## Step 5.5 — Fetch Confluence activity (optional)

Skip this step unless `confluence.enabled` is `true` in config.

**If enabled AND a Confluence tool is available** (Atlassian/Rovo connector for Cloud
Confluence, or a separately configured Confluence MCP for self-hosted):

Fetch pages and comments the user created or edited since `SINCE`. Use whatever
Confluence tool is present — do not hardcode a specific server or URL. Typical query:
pages/blog posts where contributor = current user, updated in the `SINCE` window.

Collect:
```json
[
  {
    "title": "Page title",
    "url": "https://...",
    "space": "SPACE",
    "action": "edited",
    "at": "ISO-timestamp"
  }
]
```

**If disabled or no Confluence tool is available:**

Set `confluence_activity: []`. Skip silently.

---

## Step 6 — Compose virtual log

Build in memory — do **not** write to disk:

```json
{
  "collected_at": "<now-iso>",
  "since": "<SINCE>",
  "sources": {
    "jira": {"events": [...]},
    "github": {"events": [...], "skipped": false},
    "confluence": {"events": [...], "skipped": false},
    "calendar": {"events": [...]}
  }
}
```

---

## Step 7 — Get last evening message for context

Use `LAST_STANDUP_TEXT` from Step 1 if available. If not found in Step 1, run one
more `slack_search_public_and_private` with `from:me in:{publish_channel_name}` scoped
to last 14 days and take the most recent result. Store as context for the draft.

---

## Step 8 — Fetch Slack activity since last standup

Run MCP `slack_search_public_and_private` calls (can run in parallel):

- **Outbound**: `from:me after:{SINCE}`
- **Inbound DMs**: `to:me after:{SINCE}`

**Channel scope:**
- If `input_slack_channels` is set and non-empty in config: add per-channel filters.
- Otherwise: use global search (no channel restriction) — this is the default.

Collect all returned messages as supplemental activity evidence.

---

## Step 8.5 — Load style overlay

Look for personal style overlay in this order:
1. **Project knowledge file** — scan context for a file with standup style guide
   (typically named `style.md` or containing "Standup style", "phrasing patterns",
   "language:" markers).
2. **Filesystem** (Claude Code only) — read `config/style.md` from the current workspace
   via the Read tool, if it exists.
3. If neither found — proceed with universal defaults only.

Store as `STYLE_OVERLAY` string (raw markdown content).

---

## Step 8.6 — Aggregate evidence via subagent

Invoke the `standup-aggregate` skill as a subagent (via `Agent` tool,
`subagent_type: general-purpose`), passing:
- The virtual log JSON from Step 6.
- The combined Slack dump from Step 8.
- `style_overlay: <STYLE_OVERLAY content>` (or omit if not found).
- Calendar events from Step 5 as additional input for the `meetings_from_calendar` field.
- Confluence activity from Step 5.5 as additional input (if any).

The subagent returns **activity cards** — one per Jira key, plus a "no-key" tail.
Store the cards as primary input for Step 9.

---

## Step 9 — Draft the message

Invoke the `standup-format` skill, passing:
- Activity cards from Step 8.6 (primary).
- Last evening message text (Step 7) as style/context reference.
- `style_overlay: <STYLE_OVERLAY content>` (or omit if not found).
- Note: `local_git_activity` is null — infer commit activity from GitHub source only.

---

## Step 9.5 — Validate formatting

Before showing the draft, verify all six rules. If any check fails, invoke
`standup-format` once more with an explicit correction prompt, then re-check:

1. Date headers use `**DD.MM**` (two asterisks). No other bold in the body.
2. No `__` anywhere in the body.
3. Exactly one blank line between the `**DD.MM**` header for yesterday and the
   `**DD.MM**` header for today/tomorrow.
4. Every non-blank, non-header line inside a date block starts with `• ` (U+2022 + space) — no content line may be missing the bullet prefix.
5. Every Jira reference uses `<URL|KEY>` form, not a bare URL.
6. No raw Jira status in parentheses anywhere in the body (e.g. `(Ready for QA)`, `(In QA)`, `(In Progress)`).

---

## Step 10 — Self-DM preview

1. Get `my_user_id`:
   - From `slack_user_id` in config.
   - If missing: call `slack_search_users` with `email` from config.
     Show result to user, ask to confirm.
2. Send draft via MCP `slack_send_message` to `channel = my_user_id`.
3. Show the user the permalink of the sent DM.

---

## Step 11 — Ask what to do next

Present exactly these four options and wait for the user's choice:

1. **Опубликовать в {publish_channel_name}** — send via MCP `slack_send_message`
   to channel `{publish_channel_id}`.
2. **Редактировать** — ask the user to type their edits in the chat.
   Apply edits to the draft, re-run Step 9.5 validation, repeat Step 10 preview.
   Do **not** try to open a file — editing happens in the conversation.
3. **Отправлю вручную** — user sends manually. Done.
4. **Не сегодня** — stop. Show the draft text in the chat so the user can copy it.

---

## Do NOT

- Do NOT publish to the standup channel without explicit user confirmation (option 1 in Step 11).
- Do NOT run any shell scripts or bash commands.
- Do NOT write any files — no `logs/`, no `drafts/`, no `archive/`, no `state.json`.
- Do NOT fail if GitHub MCP, Google Calendar MCP, or Confluence is unavailable — skip gracefully.
