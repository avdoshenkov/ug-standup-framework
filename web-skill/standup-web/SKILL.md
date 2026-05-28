---
name: standup-web
description: Evening standup collection for Claude Web/Desktop/Mobile. Collects activity from Slack, Jira, and Google Calendar (optional) and composes a formatted Slack standup message. No subagents, no filesystem, no shell. Triggered by "собери стендап", "evening standup", "подготовь вечернее письмо", "web standup", "что я делал сегодня".
---

# Standup Web — Self-Contained

Collect today's activity and produce a formatted Slack standup message.
Works in Claude Web, Desktop, and Mobile. No shell. No filesystem. No subagents.
All data via MCP connectors: Slack (required), Atlassian (required), Google Calendar (optional).
GitHub activity is not included — no GitHub connector available in web project chat.

Nothing is written to disk. No state file. Each run is self-contained.

---

## Step 0 — Load config

Scan conversation context (system message, project instructions, knowledge files) for a YAML block with standup config. Required fields:

```yaml
email: you@example.com
slack_user_id: UXXXXXXXX
publish_channel_id: CXXXXXXXX
publish_channel_name: "#channel-name"    # must be quoted — # starts a YAML comment
jira_project: PROJ
jira_board_id: 123
atlassian_domain: company.atlassian.net
calendar_id: primary          # optional
input_slack_channels: []      # optional — default: global search
confluence:
  enabled: false              # optional
```

If config not found, stop and tell the user:
> Нет конфига. Добавь YAML-блок в project instructions или приложи `config.md` файлом.
> Обязательно: `slack_user_id`, `publish_channel_id`, `jira_project`, `atlassian_domain`.

Do NOT proceed without at least: `slack_user_id`, `publish_channel_id`, `jira_project`, `atlassian_domain`.

---

## Step 1 — Resolve `since`

Compute the window start from the last posted standup:

1. Call MCP `slack_search_public_and_private` with query `from:me in:{publish_channel_name}`, scoped to last 7 days.
2. If found: take the most recent post's timestamp as `SINCE`. Store full text as `LAST_STANDUP_TEXT`.
3. If not found:
   - Today is Monday → `SINCE` = last Friday 00:00 local time.
   - Otherwise → `SINCE` = yesterday 00:00 local time.
   - `LAST_STANDUP_TEXT` = "".

Store:
- `SINCE` — ISO-8601 with timezone (e.g. `2026-05-27T00:00:00+03:00`)
- `SINCE_DATE` — date only (`YYYY-MM-DD`)
- `LAST_STANDUP_TEXT`

---

## Step 2 — Resolve current sprint

Call MCP `searchJiraIssuesUsingJql` with JQL:
`assignee = currentUser() AND sprint in openSprints()`

Build sprint task list: `[{key, summary, status, url}]`

If fails or empty: set sprint name to `""`, tasks to `[]`. Do not stop.

---

## Step 3 — Fetch Jira activity

1. Call MCP `searchJiraIssuesUsingJql`:
   `assignee = currentUser() AND updated >= '${SINCE_DATE}'`
2. For each returned key call MCP `getJiraIssue` for changelog and comments.
3. Build per-key entry:
   ```
   {key, summary, url, status,
    status_changes: [{from, to, at}],   ← only entries at >= SINCE
    comments_by_me: [{at, body}]}
   ```

If no activity: `jira_events: []`. Continue.

---

## Step 5 — Fetch Calendar events (optional)

**Attempt calendar fetch** — if the calendar connector is enabled but `list_events` is not immediately visible in the active tool set, attempt one call before concluding unavailable:

Call `list_events`:
- Calendar: `calendar_id` from config (default: `primary`)
- Time range: from `SINCE` to `now + 1 day`
- Filter: attendee or organizer; exclude declined.

Collect: `[{summary, start, end, status}]`

**Only if the call genuinely fails or the tool does not exist:** `calendar_events: []`. Do not fail.

---

## Step 8 — Fetch Slack activity

Run in parallel:
- **Outbound**: `slack_search_public_and_private` — `from:me after:{SINCE_DATE}`
- **Inbound DMs**: `slack_search_public_and_private` — `to:me after:{SINCE_DATE}`

If `input_slack_channels` non-empty in config: add per-channel filters. Otherwise: global search.

Collect `slack_outbound` and `slack_inbound` message lists.

For inbound DMs mentioning a Jira key (regex `[A-Z]+-\d+`):
call `slack_read_thread` (cap 5 threads) to get context. Store per-key `slack_dm_context`.

---

## Step 8.5 — Load style overlay

Scan context for a file with standup style guide (named `style.md` or containing
"Standup style", "phrasing patterns", "language:" markers).

If found: store as `STYLE_OVERLAY` (raw markdown). If not: `STYLE_OVERLAY` = "".

---

## Step 9 — Aggregate and draft

### 9.1 Build activity cards

Collect all Jira keys from: `jira_events[].key` + Slack outbound + Slack inbound
(regex `[A-Z]+-\d+`). Deduplicate. Sprint tasks with zero activity → omit.

**Per-key card:**
```
## KEY
- summary: <Jira issue summary, one phrase>
- status: <current Jira status>
- closed_today: <true|false — status moved to Done/Closed/Released since SINCE>
- status_changes: <e.g. "In Progress → Done", or "none">
- my_jira_comments: <count>
- slack_dm_context: <≤10-word summary of relevant DM, or "none">
- one_line: <suggested bullet body — past tense, ≤12 words>
```

`one_line` rules:
- Past tense, Russian.
- If `closed_today = true`: lead with a "deployed / closed / released" verb.
- If `slack_dm_context` reveals collaboration: append after "—".
- If `STYLE_OVERLAY` provides a status→verb mapping: use it.
- Otherwise: use Jira status label translated to Russian.
- Do NOT append the Jira status in parentheses. Status informs verb choice only — never appears in output.

**Keyless tail:**
```
## no-key
- code_reviews: <count of PRs reviewed (not authored), or "none">
- meetings: <notable meetings only — kick-offs, 1-on-1s, planning, demos, retros; from calendar_events first (exclude routine recurring calls), then Slack keyword scan; "none" if absent>
- incidents: <infra/deploy issues, or "none">
```

---

### 9.2 Draft the message

Format using **Slack mrkdwn** (not Markdown):

| Element | Correct | Incorrect |
|---|---|---|
| Bold (date) | `**30.04**` | ~~`*30.04*`~~ (italic) |
| Bullet | `• ` (U+2022 + space) | ~~`- `~~ ~~`* `~~ |
| Jira link | `<https://...\|KEY>` | ~~bare URL~~ |
| Headers | do not use | ~~`## header`~~ |
| Code blocks | do not use | ~~` ``` `~~ |

**Structure:**
```
**DD.MM**
• <JIRA-URL|KEY> — short title. Action done (past tense, Russian)
• Non-ticket activity (meeting, code review)

**DD+1.MM**
• <JIRA-URL|KEY> — short title. What I plan (infinitive, Russian)
```

Rules:
- Exactly one blank line between yesterday and today date blocks.
- Bullet order: `• <KEY> — action` (never `• action <KEY>`).
- Short title after the link: 3–5 words, NOT the full Jira title — distil the essence.
- Use `LAST_STANDUP_TEXT` as style reference if available.
- Apply `STYLE_OVERLAY` phrasing patterns and verb table if loaded.
- No preamble. No markdown fences. Output only the message text.

Build Jira link: `https://{atlassian_domain}/browse/{KEY}`

---

## Step 9.5 — Validate formatting

Before showing the draft, verify all six rules. If any fail: self-correct and re-check.

1. Date headers use `**DD.MM**` (two asterisks). No other bold in the body.
2. No `__` anywhere.
3. Exactly one blank line between yesterday and today date headers.
4. Every non-blank, non-header line inside a date block starts with `• ` (U+2022 + space) — no content line may be missing the bullet prefix.
5. Every Jira reference uses `<URL|KEY>` form.
6. No raw Jira status in parentheses anywhere in the body (e.g. `(Ready for QA)`, `(In QA)`, `(In Progress)`).

---

## Step 10 — Self-DM preview

1. `my_user_id` = `slack_user_id` from config. If missing: call `slack_search_users`
   with `email` from config, show result, ask user to confirm.
2. Send draft via MCP `slack_send_message` to `channel = my_user_id`.
3. Show the permalink of the sent DM.

---

## Step 11 — Ask what to do next

Present exactly these four options and wait for user choice:

1. **Опубликовать в {publish_channel_name}** — send via `slack_send_message` to `{publish_channel_id}`.
2. **Редактировать** — user types edits in chat. Apply, re-run Step 9.5, repeat Step 10 preview.
3. **Отправлю вручную** — done.
4. **Не сегодня** — stop. Show draft text in chat for copying.

---

## Do NOT

- Do NOT publish to the team channel without explicit user confirmation (option 1 above).
- Do NOT run shell commands or bash.
- Do NOT write any files — no logs, no drafts, no archive, no state.json.
- Do NOT fail if Google Calendar MCP is unavailable — skip gracefully.
- Do NOT dispatch subagents — aggregation and formatting are inlined in Step 9.
