---
name: standup-backfill
description: Pull all standup messages from the Slack publish channel and save them as local archive files. Run periodically (e.g. weekly) to keep a searchable offline archive. Triggered by /standup-archive, "выгрузи историю", "выгрузи стендапы из Slack".
---

# Standup Backfill

Pull standup messages from the configured Slack publish channel and save them as
local archive files. Run from Claude Code (requires filesystem write access).

Use this periodically — weekly or on demand — to keep a searchable offline archive
in `archive/`. Each run skips files that already exist, so it is safe to re-run.

---

## Step 0 — Load config

Read `config/local.json` from the current workspace via the Read tool.

Required fields:
- `team.publish_channel_id` → `PUBLISH_CHANNEL_ID`
- `team.publish_channel_name` → `PUBLISH_CHANNEL_NAME`
- `team.slack_workspace_domain` → `WORKSPACE_DOMAIN`
- `user.slack_user_id` → `MY_USER_ID`

If the file is missing or required fields are absent, stop and tell the user to run
`/standup-init` to create the data repo config.

---

## Step 1 — Validate prerequisites

1. Use `MY_USER_ID` from `config/local.json` (Step 0). If absent or empty:
   - Tell the user: "slack_user_id не задан в config/local.json."
   - **Stop.**
2. Note how many files already exist in `archive/` (to report at the end).

---

## Step 2 — Fetch all messages from publish channel

Use `STANDUP_PUBLISH_CHANNEL_ID` as the channel. Try the approaches in order.

### Approach A — slack_read_channel (preferred)

Call MCP `slack_read_channel` for channel `${STANDUP_PUBLISH_CHANNEL_ID}`:
- Use cursor-based pagination: keep calling with the returned `next_cursor` until it is empty or absent.
- From each page, collect only messages where `user == MY_USER_ID`.
- Build a list of all matching messages: `[{ts, text, permalink_ts}, ...]`.

### Approach B — slack_search_public_and_private (fallback)

If `slack_read_channel` is unavailable or returns an error, use:
- Query: `from:<MY_USER_ID> in:${STANDUP_PUBLISH_CHANNEL_NAME}`
- Paginate through all result pages until no more results.
- Collect all returned messages into the same list format.

> Note: `slack_search_public_and_private` may miss messages older than ~1–2 years depending on workspace plan limits. Log a warning if results seem to stop abruptly at a certain date.

---

## Step 3 — Process each message

For each collected message, in chronological order (oldest first):

1. **Determine the work date** (not the post date).
   - Scan the first ~6 non-empty lines of the message body for the first
     token matching `^\*?(\d{1,2})\.(\d{1,2})(?:\*?[\s,]|\*?$)`. This captures
     formats like `27.03`, `*27.03*`, `26.08 и 27.08`, `26.09, 27.09`.
     The matched `DD.MM` is the **work date** the report is about.
   - Derive the year from the Slack `ts` (UTC). Adjust for year-boundary posts:
     if `body_month - ts_month > 6` → `year - 1`; if `ts_month - body_month > 6`
     → `year + 1`.
   - If no `DD.MM` is found in the body, fall back to the `ts` date (UTC) and
     log a warning.
   - Use this date as `YYYY-MM-DD` for the archive file and the `date:` frontmatter
     field. `published_at` stays as the actual Slack post timestamp.

   > **Why:** The same Slack channel routinely receives two reports per calendar
   > day — a morning post covering the previous work day, and an evening post
   > covering the current day. A morning post on `2026-03-30T08:44Z` whose body
   > opens with `27.03` must be archived as `archive/2026-03-27.md`, not
   > `archive/2026-03-30.md`.

2. **Build the archive filename.**
   - `target = archive/{work_date}.md`, where `work_date` is from item 1.
   - On collision (file already exists), pick the smallest `-N` suffix
     (`-1`, `-2`, …) that keeps all files for this work date ordered by
     `published_at` ascending. Iterate messages chronologically (oldest first)
     so that the unsuffixed file is always the earliest post for that work date.

3. **Build the permalink URL.**
   - Remove the `.` from `ts` to get the raw timestamp (e.g., `1693000000123456`).
   - URL: `https://${STANDUP_SLACK_WORKSPACE_DOMAIN}/archives/${STANDUP_PUBLISH_CHANNEL_ID}/p<ts_without_dot>`

4. **Determine sprint.**
   - Leave `sprint` as an empty string `""`.

5. **Write the archive file** with this exact format:

```markdown
---
date: YYYY-MM-DD
sprint: ""
slack_permalink: https://${STANDUP_SLACK_WORKSPACE_DOMAIN}/archives/${STANDUP_PUBLISH_CHANNEL_ID}/p<ts_without_dot>
status: imported
published_at: YYYY-MM-DDTHH:MM:SS.ffffffZ
---

<message text here>
```

   - `published_at` is the ISO 8601 representation of the Slack `ts` (UTC).
   - Do NOT modify the message text — preserve it exactly as received from Slack.

---

## Step 4 — Summary report

After processing all messages, print:

```
Выгрузка завершена.
  Найдено сообщений : <N>
  Создано файлов    : <M>
  Пропущено файлов  : <K>  (уже существуют)
  Диапазон дат      : <earliest-date> → <latest-date>
  Папка архива      : archive/
```

If the search appears to have cut off before reaching the earliest expected messages, add a warning:

```
ПРЕДУПРЕЖДЕНИЕ: Результаты могут быть неполными из-за ограничений поиска Slack.
                Самое раннее сообщение: <date>. Проверь Slack вручную для более старых сообщений.
```

---

## Do NOT

- Do NOT overwrite an existing archive file — use a `-1`, `-2` suffix instead.
- Do NOT publish or send any messages to Slack.
- Do NOT edit or delete any existing files other than creating new `archive/` entries.
