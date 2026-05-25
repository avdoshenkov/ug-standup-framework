---
name: standup-format
description: Draft the evening standup Slack message summarising the day. Use whenever the user wants to compose a daily/evening standup, day summary, or says something like "напиши стендап", "оформи итоги дня", "составь сообщение о том, что делал", "напиши что вчера делал".
---

# Standup Format Skill

Composes the evening Slack standup message from the user's verbal or text input.

---

## Step 0.5 — Load personal style overlay (optional)

Load style overlay from the **first available source**:

1. **`style_overlay` input parameter** — if the calling skill passed `style_overlay`
   as explicit content (Web/MCP mode), use that directly.
2. **Filesystem** — if `${STANDUP_DATA_DIR}/config/style.md` exists, read it.
3. If neither is available, proceed with universal rules only — output will still be
   valid Slack mrkdwn but phrased generically.

Treat the loaded content as user-authored style guidance that **overrides or augments**
the universal rules below.

---

## Context and style

The message is posted to the corporate Slack standup channel. Style: business-like,
concise, no fluff. Output only the message — no preamble, no explanations.

Language and specific phrasing are defined in `config/style.md`. If that file is
absent, use the language of the user's input.

---

## Formatting rules

**CRITICAL — Slack mrkdwn, not Markdown:**

The message is published in Slack. Slack uses its own mrkdwn syntax that **differs**
from standard Markdown. Breaking the rules below = broken rendering for the whole team.

| Element | Correct | Incorrect |
|---|---|---|
| Bold (date) | `**30.04**` — two asterisks | ~~`*30.04*`~~ — one asterisk, renders as italic |
| Italic | `_текст_` | not used in standups |
| Bullet | `• ` (U+2022 + space) | ~~`- `~~ ~~`* `~~ |
| Jira link | `<https://...\|PROJ-XXXXX>` | ~~`https://...`~~ bare URL |
| Headers | do not use | ~~`## заголовок`~~ |
| Quotes / code blocks | do not use | ~~`> цитата`~~ ~~` ```блок``` `~~ |

> Note: single asterisk renders as italic in Slack mrkdwn; `**` gives bold.

**Required — blank line between blocks:**
Between the "yesterday" date and the "today" date — exactly one blank line (`\n\n`).
Without it the blocks merge.

```
CORRECT:
**30.04**
• <https://jira.example.com/browse/PROJ-123|PROJ-123> — did something

**01.05**
• <https://jira.example.com/browse/PROJ-456|PROJ-456> — to do

INCORRECT:
*30.04*               ← one asterisk: renders as italic
• ...
**01.05**             ← no blank line before next date
```

Other rules:
- **Bullet order with Jira key**: `• <KEY> — verb action`. Never put the verb before
  the link (`• verb <KEY>` → wrong; `• <KEY> — verb` → correct).
- Task description: brief, past tense for "yesterday", future/infinitive for "today".
- No commentary from the model — only the message itself.
- No trailing blank line at the end of the message.

---

## Input data

**Optional parameter: `style_overlay`** — raw markdown content of the style file,
passed by the calling skill (used in Web/MCP mode instead of filesystem read).
If provided, Step 0.5 uses this content directly.

**A. Activity cards (preferred)** — when called from `standup-collect` via
`standup-aggregate`. Format:
```
## PROJ-XXXXX
- one_line: did something
- closed_today: true
- prs: #2176 merged
- slack_dm_context: none
...

## no-key
- code_reviews: several
- meetings: sync on X
```
Use the `one_line` field as the basis for the bullet. Supplement with context from
other card fields as needed.

**B. Free-form user input** — voice or text. Apply the drafting algorithm below.

---

## Drafting algorithm

### 1. Gather context

The user describes their day verbally or in text — often unstructured. Extract
the essence.

If the user provides a link to a previous Slack message — read it
(`slack_read_thread`) to understand the format and style for that channel/team.

If the user says "look at Jira tasks" — search current sprint tasks assigned to
the user (`assignee = currentUser() AND sprint in openSprints()`).

### 2. Message structure

Two blocks:

**Yesterday (date)**
- what was done during the past day
- each task as a separate bullet
- status: what was done, what remains

**Today (date)**
- what is planned
- tasks and meetings as separate bullets
- meetings written without tickets (e.g. "Sprint planning", "Kick-off on X")

### 3. Jira tasks

- If the user mentions a ticket number — use it.
- If the user describes a task without a number — try to find a match in the sprint
  by meaning.
- Take wording from the user's description, not the Jira ticket title.
- Link format: `https://${STANDUP_ATLASSIAN_DOMAIN}/browse/${STANDUP_JIRA_PROJECT}-XXXXX`
  (resolve from config or context).

### 4. Slack and DM context

If input includes Slack activity (incoming/outgoing DMs, channel messages):

1. **DM mentioning a sprint Jira key** → include the collaboration in that task's
   bullet.
2. **PR-review pings** → include as "code review on X" (or per style.md phrasing).
3. **Incoming DMs without a Jira key** → ignore.
4. **Do not quote DMs verbatim** — paraphrase, third person.

### 5. Complex descriptions in one bullet

If multiple things were done on one task, or there is important context — describe
everything in one bullet, separated by commas or a period.

---

## Output format

Output only the ready message text — no explanations, no "here's your message:",
no markdown code blocks. Just the text that can be copied and pasted into Slack.
