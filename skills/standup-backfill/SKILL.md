---
name: standup-backfill
description: Backfill historical standup messages from Slack publish channel into the local archive. Triggered by /standup-archive, "выгрузи историю", "выгрузи стендапы из Slack".
---

# Standup Backfill

Pull all historical evening standup messages from the configured Slack publish channel
and save them as local archive files.

---

## Step 0 — Load config

Source `${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh` to export `STANDUP_*` env vars.
Required: `STANDUP_PUBLISH_CHANNEL_ID`, `STANDUP_PUBLISH_CHANNEL_NAME`,
`STANDUP_SLACK_WORKSPACE_DOMAIN`.

---

## Step 1 — Validate prerequisites

1. Read `config/state.json`.
2. Check `my_user_id` (or `STANDUP_SLACK_USER_ID` from config). If both are null or empty:
   - Tell the user: "my_user_id не задан — сначала запусти /standup, чтобы Claude нашёл и сохранил твой Slack user ID."
   - **Stop.**
3. Store the resolved value as `MY_USER_ID` for the steps below.
4. Note how many files already exist in `archive/` (to report at the end).

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

4. **Determine sprint (best effort).**
   - Check `current_sprint` in `config/state.json`.
   - If set and the message date falls within the current sprint, use it.
   - Otherwise leave `sprint` as an empty string `""`.

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
- Do NOT modify `config/state.json` during this backfill (it is a historical import).
- Do NOT publish or send any messages to Slack.
- Do NOT edit or delete files in `logs/` or `drafts/`.
