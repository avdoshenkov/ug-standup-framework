---
name: standup-collect-web
description: Universal MCP-only evening standup collection — works in Claude Web, Mobile, Desktop chat, Claude Code cloud, and Claude Code CLI. No bash, no local filesystem required. All data fetched via Slack MCP, Atlassian MCP, GitHub MCP, and Google Calendar MCP. Config loaded from project knowledge file or data-repo. Triggered by "собери стендап", "evening standup", "web standup", "подготовь вечернее письмо".
---

# Standup Collect — Universal Web Mode

Collect today's activity and produce a formatted Slack standup message. Works in any
Claude environment: Web, Mobile, Desktop chat, Claude Code cloud, Claude Code CLI.
No bash required. No local filesystem required. All data via MCP connectors.

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
data_repo: owner/repo         # optional — GitHub repo for state + archive
github_branch: main           # optional — default: main
input_slack_channels: []      # optional — default: global search
```

If found and contains all required fields, extract values. Proceed to Step 0.5.

### Source A2 — Minimal project instructions + data-repo config (recommended)

If the project instructions contain **only** a `data_repo` pointer (with no other
standup config fields), fetch the full config from the data-repo via GitHub MCP:

```
GET https://api.github.com/repos/{data_repo}/contents/config/local.json
```

Parse the JSON and map fields:

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
```

This is the **recommended mode**: project instructions are a one-liner, all config
lives in the data-repo alongside state and archive. A single `git push` to the
data-repo propagates config changes to all Claude environments automatically.

Required project instructions format for this mode:
```yaml
data_repo: owner/repo
github_branch: main   # optional, default main
calendar_id: primary  # optional
```

If found, extract combined values (project instructions + data-repo config). Proceed to Step 0.5.

### Source B — Filesystem fallback (only when Bash tool is available)

If Source A is not found AND the Bash tool is available, try:
```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh" && echo "PUBLISH_CHANNEL_ID=$STANDUP_PUBLISH_CHANNEL_ID" && echo "EMAIL=$STANDUP_EMAIL" && echo "SLACK_USER_ID=$STANDUP_SLACK_USER_ID" && echo "JIRA_PROJECT=$STANDUP_JIRA_PROJECT" && echo "JIRA_BOARD_ID=$STANDUP_JIRA_BOARD_ID" && echo "ATLASSIAN_DOMAIN=$STANDUP_ATLASSIAN_DOMAIN" && echo "GH_ORG=$STANDUP_GH_ORG" && echo "GH_REPOS=$STANDUP_GH_REPOS" && echo "DATA_DIR=$STANDUP_DATA_DIR"'
```

Map `STANDUP_DATA_DIR` → `data_repo_path` (local path, not GitHub owner/repo).
Note: in this mode, archive/state are read/written via filesystem (no GitHub MCP needed).

### Source C — Fail gracefully

If neither source is found, stop and tell the user:

> ⚠️ Конфиг не найден. Добавь YAML-блок с настройками в project instructions или knowledge file проекта. Шаблон: `web-template/config.template.md` в репозитории плагина.

Do NOT proceed without at least: `slack_user_id`, `publish_channel_id`, `jira_project`, `atlassian_domain`.

---

## Step 0.5 — Warning

Print, exact text:

> ⚠️ Универсальный Web-режим. Локальные git-коммиты и незакоммиченные изменения НЕ собираются.
> GitHub-активность (PRs, commits) подтягивается через GitHub MCP, если он подключён.

Do not wait for acknowledgement — continue immediately.

---

## Step 1 — Resolve `since` and load state

### If `data_repo` is set (GitHub sync enabled):

Call GitHub MCP to read state file:
- Tool: fetch `https://api.github.com/repos/{data_repo}/contents/config/state.json`
  (use whatever GitHub MCP tool is available — `get_file_content`, `fetch_file`, etc.)
- Decode base64 content, parse JSON.
- If `last_run` is present → use as `SINCE`.
- Store full state object for later writes.

### If `data_repo_path` is set (fs fallback, Code CLI only):

Read `{data_repo_path}/config/state.json` via filesystem. Extract `last_run` as `SINCE`.

### If no state available:

Fallback:
- If today is Monday → last Friday at 00:00 local time.
- Otherwise → yesterday at 00:00 local time.

Store:
- `SINCE` — full ISO-8601 with timezone (e.g., `2026-04-28T00:00:00+03:00`)
- `SINCE_DATE` — date only (`YYYY-MM-DD`, for JQL filters)

---

## Step 2 — Resolve current sprint

### Sprint cache check:

If state JSON has `current_sprint.fetched_at` less than 3 days old →
reuse `{id, name, board_id, tasks}` and skip MCP call.

### Fetch sprint via Atlassian MCP:

Call `searchJiraIssuesUsingJql` with JQL:
`assignee = currentUser() AND sprint in openSprints()`

Inspect response to find active sprint id and name.
Build sprint task list:
`tasks: [{key, summary, status, url, updated_today: false}, ...]`

### Write sprint cache (if state storage available):

Update `current_sprint` in state JSON:
`{id, name, board_id: jira_board_id, tasks, fetched_at: <now-iso>}`

Write back via GitHub MCP (or fs if Code CLI). Do NOT create state file if it does not exist.

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
3. If `jira_account_id` is missing from config or state, leave comment arrays empty.

---

## Step 4 — Fetch GitHub activity via MCP

**If GitHub MCP is available** (check by attempting a minimal call):

For each repo in `gh_repos`:

1. **PRs authored by me** — search for PRs:
   Query: `is:pr author:@me repo:{repo} updated:>={SINCE_DATE}`
   Or use GitHub MCP search/list PRs endpoint.
   Collect: `{number, title, state, url, merged_at, updated_at, base_branch}`

2. **Commits by me** — list commits in repo since SINCE for authenticated user.
   Collect: `{sha, message, url, date, branch}`

3. **PR review requests** — PRs where I'm requested reviewer, updated since SINCE.
   Collect: `{number, title, url, author}`

Build GitHub events:
```json
{
  "prs": [...],
  "commits": [...],
  "review_requests": [...]
}
```

**If GitHub MCP is NOT available:**

Set `github_activity: null`. Add note in Step 6 virtual log. Do not fail — continue.

---

## Step 5 — Fetch Calendar events

**If Google Calendar MCP is available:**

Call `list_events` (or equivalent tool):
- Calendar: `calendar_id` from config (default: `primary`)
- Time range: from `SINCE` to `now + 1 day`
- Filter: only events where user is attendee OR organizer

Collect events:
```json
[
  {
    "summary": "Sprint planning",
    "start": "2026-05-22T10:00:00",
    "end": "2026-05-22T11:00:00",
    "status": "accepted"   // accepted / tentative / declined
  }
]
```

Exclude declined events.

**If Google Calendar MCP is NOT available:**

Set `calendar_events: []`. Do not fail.

---

## Step 6 — Compose virtual log object

Build in memory — do **not** write to `logs/`:

```json
{
  "collected_at": "<now-iso>",
  "since": "<SINCE>",
  "mode": "web",
  "sources": {
    "jira": {"events": [...]},
    "github": {"events": [...], "skipped": false},
    "git": {"skipped": "not available in web mode"},
    "calendar": {"events": [...]}
  }
}
```

---

## Step 7 — Get last evening message for context

1. Read `last_evening_message` from state (Step 1). If it has a `permalink`:
   - Use MCP `slack_read_thread` with that permalink to retrieve message text.
2. If no permalink in state:
   - Use MCP `slack_search_public_and_private` with query
     `from:me in:{publish_channel_name}` scoped to last 7 days.
   - Take the most recent result as "last standup text".
3. Store as context for the draft.

---

## Step 8 — Fetch Slack activity since last standup

Run MCP `slack_search_public_and_private` calls (can run in parallel):

- **Outbound**: `from:me after:{SINCE}`
- **Inbound DMs**: `to:me after:{SINCE}`
- **PR review pings**: scan GitHub notification channels (if any in config) for
  review-request notifications mentioning my handle.

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
2. **Filesystem** (Code CLI only) — read `{data_repo_path}/config/style.md` if exists.
3. **GitHub MCP** (if `data_repo` set) — fetch `config/style.md` from data-repo.
4. If none found — proceed with universal defaults only.

Store as `STYLE_OVERLAY` string (raw markdown content).

---

## Step 8.6 — Aggregate evidence via subagent

Invoke the `standup-aggregate` skill as a subagent (via `Agent` tool,
`subagent_type: general-purpose`), passing:
- The virtual log JSON from Step 6.
- The combined Slack dump from Step 8.
- `style_overlay: <STYLE_OVERLAY content>` (or omit if not found).
- Calendar events from Step 5 as additional input for the `meetings_from_calendar` field.

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

Before saving the draft, verify all five rules. If any check fails, invoke
`standup-format` once more with an explicit correction prompt, then re-check:

1. Date headers use `**DD.MM**` (two asterisks). No other bold in the body.
2. No `__` anywhere in the body.
3. Exactly one blank line between the `**DD.MM**` header for yesterday and the
   `**DD.MM**` header for today/tomorrow.
4. Every bullet line starts with `• ` (U+2022 + space).
5. Every Jira reference uses `<URL|KEY>` form, not a bare URL.

---

## Step 10 — Self-DM preview

1. Get `my_user_id`:
   - From state JSON if present.
   - From `slack_user_id` in config.
   - If both missing: call `slack_search_users` with `email` from config.
     Show result to user, ask to confirm.
     Write to state JSON (only if state file already exists).
2. Send draft via MCP `slack_send_message` to `channel = my_user_id`.
3. Show the user the permalink of the sent DM.

---

## Step 11 — Ask what to do next

Present exactly these four options and wait for the user's choice:

1. **Опубликовать в {publish_channel_name}** — send via MCP `slack_send_message`
   to channel `{publish_channel_id}` → capture returned permalink → proceed to Step 12.
2. **Редактировать** — ask the user to type their edits in the chat.
   Apply edits to the draft, re-run Step 9.5 validation, repeat Step 10 preview.
   Do **not** try to open a file — editing happens in the conversation.
3. **Отправлю вручную** — user sends manually, then returns with permalink → proceed to Step 12.
4. **Не сегодня** — stop. Do not archive. Show the draft text in the chat so the user can copy it.

---

## Step 12 — Archive after confirmed publication

### Determine archive date:

Scan the first ~6 non-empty lines of the message body for the first `DD.MM` token
(regex `^\*?(\d{1,2})\.(\d{1,2})(?:\*?[\s,]|\*?$)`). Use that date with current year
as archive date. If no `DD.MM` found, fall back to today's date.

### Write archive entry:

Build archive file content:

```yaml
---
date: YYYY-MM-DD
sprint: "Sprint Name"
slack_permalink: https://...
status: published
published_at: ISO-timestamp
---

{message body}
```

**If `data_repo` is set (GitHub MCP):**

Commit `archive/{archive-date}.md` to data-repo via GitHub MCP:
- Check if file already exists (GitHub MCP `get_file_content`). If yes — tell user and stop.
- Create/update file via GitHub MCP (`create_or_update_file_contents` or equivalent).
- Commit message: `archive: standup {archive-date}`

**If `data_repo_path` is set (Code CLI, fs):**

Write file to `{data_repo_path}/archive/{archive-date}.md`.
Check existence before writing — do NOT overwrite.

**If no storage configured:**

Display the archive file content in the chat. Tell the user:
> Архив не настроен. Скопируй текст ниже в `archive/{date}.md` вручную, или укажи `data_repo` в конфиге для автосохранения.

### Update state:

Update `last_evening_message` in state JSON:
```json
{
  "ts": "slack_message_ts",
  "permalink": "https://...",
  "archived_at": "ISO-timestamp",
  "sprint_name": "Sprint Name"
}
```

Use `current_sprint.name` from state if set; otherwise empty string.

Write state back via GitHub MCP (or fs). Create/update the file with merged content.

---

## Do NOT

- Do NOT publish to the standup channel without explicit user confirmation (option 1 in Step 11).
- Do NOT run any shell scripts or bash commands in hot path (Steps 3–12).
- Do NOT write `logs/{date}.json`.
- Do NOT create `config/state.json` (in data-repo or fs) if it does not already exist.
- Do NOT create a duplicate archive entry if `archive/YYYY-MM-DD.md` already exists.
- Do NOT fail if GitHub MCP or Google Calendar MCP is unavailable — skip gracefully.
