---
name: standup-collect-cloud
description: Cloud-mode evening standup collection — no local git repos, no logs/{date}.json required. All data fetched on-the-fly via Atlassian MCP, Slack MCP, and gh CLI. Triggered by /standup-cloud, "облачный стендап", "стендап без локалки".
---

# Standup Collect — Cloud Mode

Collect today's activity and produce a formatted Slack standup message — without
running `scripts/collect-standup.sh` and without local git repo access.

---

## Step 0 — Load config

Read config values by running (use `bash -c` explicitly — config.sh uses bash-specific syntax):

```bash
bash -c 'source "${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh" && echo "PUBLISH_CHANNEL_ID=$STANDUP_PUBLISH_CHANNEL_ID" && echo "EMAIL=$STANDUP_EMAIL" && echo "SLACK_USER_ID=$STANDUP_SLACK_USER_ID" && echo "JIRA_PROJECT=$STANDUP_JIRA_PROJECT" && echo "JIRA_BOARD_ID=$STANDUP_JIRA_BOARD_ID" && echo "ATLASSIAN_DOMAIN=$STANDUP_ATLASSIAN_DOMAIN"'
```

Required: `STANDUP_PUBLISH_CHANNEL_ID`, `STANDUP_EMAIL`, `STANDUP_SLACK_USER_ID`,
`STANDUP_JIRA_PROJECT`, `STANDUP_JIRA_BOARD_ID`, `STANDUP_ATLASSIAN_DOMAIN`.

---

## Step 0.5 — Cloud-mode warning

Print to the user, exact text:

> ⚠️ Облачный режим. Локальные коммиты и незакоммиченные изменения НЕ собираются.
> Если есть незапушенные ветки — запушь их сейчас или запусти обычный /standup.

Do not wait for acknowledgement — continue immediately.

---

## Step 1 — Resolve `since`

1. If `config/state.json` exists and contains `last_run` → use that value as `SINCE`.
2. Otherwise fallback:
   - If today is Monday → last Friday at 00:00 local time.
   - Otherwise → yesterday at 00:00 local time.

Store two variables:
- `SINCE` — full ISO-8601 with timezone (e.g., `2026-04-28T00:00:00+03:00`)
- `SINCE_DATE` — date only (`YYYY-MM-DD`, for JQL filters)

---

## Step 2 — Resolve current sprint via Atlassian MCP

1. If `config/state.json.current_sprint.fetched_at` is less than 3 days old,
   reuse the cached `{id, name, board_id, tasks}` and skip the MCP call.
2. Otherwise call MCP `searchJiraIssuesUsingJql` with JQL:
   `assignee = currentUser() AND sprint in openSprints()`
   Inspect the response to find active sprint id and name.
3. Build a sprint task list from all returned issues:
   `tasks: [{key, summary, status, url, updated_today: false}, ...]`
4. If `config/state.json` exists, update `current_sprint` with
   `{id, name, board_id: $STANDUP_JIRA_BOARD_ID, tasks, fetched_at: <now-iso>}`.
   Do **not** create state.json if it does not already exist.

---

## Step 3 — Fetch Jira activity via Atlassian MCP

1. Call MCP `searchJiraIssuesUsingJql` with JQL:
   `assignee = currentUser() AND updated >= '${SINCE_DATE}'`
2. For each returned issue key:
   - Call MCP `getJiraIssue` to retrieve changelog and comments.
   - Build an activity entry:
     ```
     {
       key, summary, url, status,
       status_changes: [{from, to, at}, ...]      # filtered: created >= SINCE
       comments_by_me: [{at, body}, ...]
       comments_to_me: [{at, author, body}, ...]
     }
     ```
3. If `STANDUP_JIRA_ACCOUNT_ID` is missing, leave `comments_by_me` and `comments_to_me` as empty arrays.

---

## Step 4 — Fetch GitHub via existing helper

Run from project root:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sources/github/lib/fetch.sh" --since "${SINCE}"
```

Parse stdout as JSON and take `.github_activity` (shape: `{commits: [...], prs: []}`).

---

## Step 5 — Skip local git

Do **not** call the git source helper. Set `local_git_activity: null` in the virtual log (Step 6).

---

## Step 6 — Compose virtual log object

Build in memory — do **not** write to `logs/`:

```json
{
  "collected_at": "<now-iso>",
  "since": "<SINCE>",
  "mode": "cloud",
  "sources": {
    "jira": {"events": [...]},
    "github": {"events": [...]},
    "git": {"skipped": "not available in cloud"}
  }
}
```

---

## Step 7 — Get last evening message for context

1. Read `config/state.json`. Inspect the `last_evening_message` field.
2. If it contains a `permalink`:
   - Use MCP `slack_read_thread` with that permalink to retrieve the message text.
3. If `permalink` is absent or null:
   - Use MCP `slack_search_public_and_private` with query
     `from:me in:${STANDUP_PUBLISH_CHANNEL_NAME}` scoped to the last 7 days.
   - Take the most recent result as the "last standup text".
4. Store this text as context for the draft.

---

## Step 8 — Fetch Slack activity since last standup

1. Use `SINCE` from Step 1.
2. Run MCP `slack_search_public_and_private` calls in parallel (use `STANDUP_INPUT_SLACK_CHANNELS` if set):
   - **Outbound**: query `from:me after:<SINCE>`.
   - **Inbound DMs**: query `to:me after:<SINCE>`.
   - **PR review pings**: scan any GitHub notification channels from config for review-request notifications mentioning my handle.
3. Collect all returned messages as supplemental activity evidence.

---

## Step 8.5 — Aggregate evidence via subagent

1. Invoke the `standup-aggregate` skill as a subagent (via `Agent` tool,
   `subagent_type: general-purpose`), passing:
   - The virtual log JSON from Step 6.
   - The combined Slack dump from Step 8.
2. The subagent returns **activity cards** — one per Jira key, plus a "no-key" tail.
3. Store the cards as primary input for Step 9.

---

## Step 9 — Draft the message

1. Combine sources:
   - Activity cards from Step 8.5 (primary)
   - Last evening message text (Step 7) — as style/context reference
2. Invoke the `standup-format` skill to format the final draft.
   Note: `local_git_activity` is null — infer commit activity from `github` source only.
3. Save the draft to `drafts/YYYY-MM-DD.md` (using today's date).

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

1. Read `my_user_id` from `config/state.json` (or `STANDUP_SLACK_USER_ID` from config).
   - If null or empty:
     - Use MCP `slack_search_users` with email `${STANDUP_EMAIL}` to find the user ID.
     - Show result to user and ask to confirm.
     - On confirmation, write the ID to `config/state.json` under `my_user_id`
       **only if state.json already exists**.
2. Send the draft via MCP `slack_send_message` to `channel = my_user_id`.
3. Show the user the permalink of the sent DM.

---

## Step 11 — Ask what to do next

Present exactly these four options and wait for the user's choice:

1. **Опубликовать в ${STANDUP_PUBLISH_CHANNEL_NAME}** — send via MCP `slack_send_message` to
   channel `${STANDUP_PUBLISH_CHANNEL_ID}` → capture the returned permalink → proceed to Step 12.
2. **Редактировать** — open `drafts/YYYY-MM-DD.md` for editing, then repeat Step 10 with the revised text.
3. **Отправлю вручную** — user sends manually, then returns with permalink → proceed to Step 12.
4. **Не сегодня** — stop. Draft stays in `drafts/`. Do not archive.

---

## Step 12 — Archive after confirmed publication

1. Scan the first ~6 non-empty lines of the message body for the first `DD.MM`
   token (regex `^\*?(\d{1,2})\.(\d{1,2})(?:\*?[\s,]|\*?$)`). Use that date
   (with the current year) as the archive date. If no `DD.MM` is found, fall back to today's date.
2. Check whether `archive/{archive-date}.md` already exists. If it does,
   **do not overwrite it** — tell the user and stop.
3. Write `archive/{archive-date}.md`:

```yaml
---
date: YYYY-MM-DD
sprint: "Sprint Name"
slack_permalink: https://...
status: published
published_at: ISO-timestamp
---
```

4. Update `config/state.json` field `last_evening_message` **only if state.json exists**:

```json
{
  "ts": "slack_message_ts",
  "permalink": "https://...",
  "archived_at": "ISO-timestamp",
  "sprint_name": "Sprint Name"
}
```

Use `current_sprint` from `config/state.json` for `sprint_name` if set; otherwise empty string.

---

## Do NOT

- Do NOT publish to the standup channel without explicit user confirmation (option 1 in Step 11).
- Do NOT run `scripts/collect-standup.sh` or any local git helper.
- Do NOT write `logs/{date}.json`.
- Do NOT create a duplicate archive entry if `archive/YYYY-MM-DD.md` already exists.
- Do NOT create `config/state.json` if it does not already exist.
