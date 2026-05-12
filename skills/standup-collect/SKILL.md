---
name: standup-collect
description: Collect and prepare the evening standup Slack message. Triggered by /standup, "собери стендап", "подготовь вечернее письмо", "что я делал сегодня".
---

# Standup Collect

Collect today's activity and produce a formatted Slack standup message.

---

## Step 0 — Load config

Source `${CLAUDE_PLUGIN_ROOT}/scripts/lib/config.sh` to export `STANDUP_*` env vars.
Required: `STANDUP_PUBLISH_CHANNEL_ID`, `STANDUP_EMAIL`, `STANDUP_SLACK_USER_ID`.

---

## Step 1 — Read today's log

1. List all files in `logs/`, sort by name, take the last one.
2. Check whether its filename starts with today's date in `YYYY-MM-DD` format.
   - **Yes** → read the file.
   - **No / directory empty** → tell the user: "Лог за сегодня не найден. Сначала запусти `./scripts/collect-standup.sh`." Then **stop**.

---

## Step 2 — Get last evening message for context

1. Read `config/state.json`. Inspect the `last_evening_message` field.
2. If it contains a `permalink`:
   - Use MCP `slack_read_thread` with that permalink to retrieve the message text.
3. If `permalink` is absent or null:
   - Use MCP `slack_search_public_and_private` with query `from:me in:${STANDUP_PUBLISH_CHANNEL_NAME}` scoped to the last 7 days.
   - Take the most recent result as the "last standup text".
4. Store this text as context for the draft (so the new message doesn't repeat the same wording).

---

## Step 3 — Fetch Slack activity since last standup

1. Read the `since` field from the log JSON obtained in Step 1.
2. Run MCP `slack_search_public_and_private` calls in parallel (use channels from `STANDUP_INPUT_SLACK_CHANNELS` if set):
   - **Outbound**: query `from:me after:<since>`.
   - **Inbound DMs**: query `to:me after:<since>` — captures direct messages.
   - **PR review pings**: scan any GitHub notification channels from config for review-request notifications mentioning my handle.
3. Collect all returned messages as supplemental activity evidence.

---

## Step 3.5 — Aggregate evidence via subagent

1. Invoke the `standup-aggregate` skill as a subagent (via `Agent` tool, `subagent_type: general-purpose`), passing:
   - The full log JSON from Step 1.
   - The combined Slack dump from Step 3 (outbound + inbound DMs + PR pings).
2. The subagent returns a set of **activity cards** — one per Jira key seen in any source, plus a "no-key" tail for meetings and code reviews.
3. Store the cards as the primary input for Step 4 (drafting).

---

## Step 4 — Draft the message

1. Combine sources:
   - Activity cards from Step 3.5 (primary)
   - Last evening message text (Step 2) — as style/context reference
2. Invoke the `standup-format` skill to format the final draft.
3. Save the draft to `drafts/YYYY-MM-DD.md` (using today's date).

---

## Step 4.5 — Validate formatting

Before saving the draft, verify all five rules. If any check fails, invoke `standup-format` once more with an explicit correction prompt, then re-check:

1. No single-asterisk date headers (`*DD.MM*`) — dates must use `**DD.MM**` (double asterisk). Single asterisk renders as italic in this Slack workspace.
2. No `__` anywhere in the body.
3. Exactly one blank line between the `**DD.MM**` header for yesterday and the `**DD.MM**` header for today/tomorrow.
4. Every bullet line starts with `• ` (U+2022 + space), not `- ` or `* `.
5. Every Jira reference uses Slack link format `<URL|KEY>`, not a bare URL.

---

## Step 5 — Self-DM preview

1. Read `my_user_id` from `config/state.json` (or `STANDUP_SLACK_USER_ID` from config).
   - If null or empty:
     - Use MCP `slack_search_users` with email `${STANDUP_EMAIL}` to find the user ID.
     - Show the result to the user and ask them to confirm it is correct.
     - On confirmation, write the ID to `config/state.json` under `my_user_id`.
2. Send the draft via MCP `slack_send_message` to `channel = my_user_id` (this creates a self-DM).
3. Show the user the permalink of the sent DM.

---

## Step 6 — Ask what to do next

Present exactly these four options and wait for the user's choice:

1. **Опубликовать в ${STANDUP_PUBLISH_CHANNEL_NAME}** — send via MCP `slack_send_message` to channel `${STANDUP_PUBLISH_CHANNEL_ID}` → capture the returned permalink → proceed to Step 7.
2. **Редактировать** — open `drafts/YYYY-MM-DD.md` for editing, then repeat Step 5 with the revised text.
3. **Отправлю вручную** — the user sends from the DM or draft themselves, then returns with the permalink → proceed to Step 7.
4. **Не сегодня** — stop. The draft stays in `drafts/`. Do not archive.

---

## Step 7 — Archive after confirmed publication

1. Scan the first ~6 non-empty lines of the message body for the first `DD.MM`
   token (regex `^\*?(\d{1,2})\.(\d{1,2})(?:\*?[\s,]|\*?$)`). Use that date
   (with the current year) as the archive date. If no `DD.MM` is found, fall
   back to today's date.
2. Check whether `archive/{archive-date}.md` already exists. If it does, **do not overwrite it** — tell the user and stop.
3. Write `archive/{archive-date}.md` with this exact YAML frontmatter followed by the message body:

```yaml
---
date: YYYY-MM-DD
sprint: "Sprint Name"
slack_permalink: https://...
status: published
published_at: ISO-timestamp
---
```

4. Update `config/state.json` field `last_evening_message`:

```json
{
  "ts": "slack_message_ts",
  "permalink": "https://...",
  "archived_at": "ISO-timestamp",
  "sprint_name": "Sprint Name"
}
```

Use the `current_sprint` value from `config/state.json` for `sprint_name` / `Sprint Name` if set; otherwise leave as an empty string.

---

## Do NOT

- Do NOT publish to the standup channel without explicit user confirmation (option 1 in Step 6).
- Do NOT edit any JSON files in `logs/`.
- Do NOT create a duplicate archive entry if `archive/YYYY-MM-DD.md` already exists for today.
