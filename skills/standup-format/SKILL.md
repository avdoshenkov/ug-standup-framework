---
name: standup-format
description: Draft the evening standup Slack message summarising the day. Use whenever the user wants to compose a daily/evening standup, day summary, or says something like "напиши стендап", "оформи итоги дня", "составь сообщение о том, что делал", "напиши что вчера делал".
---
 
# Standup Format Skill
 
Composes the evening Slack standup message from the user's verbal or text input. Optionally consults Slack and Jira for details.
 
---
 
## Context and style
 
The message is posted to the corporate Slack standup channel. Style: business-like, concise, no fluff. Language: Russian. Output the message only — no preamble or explanations.
 
**Reference format** (from real user messages):
 
```
**23.04**
• <https://jira.example.com/browse/PROJ-123|PROJ-123> — что сделано, что осталось
• <https://jira.example.com/browse/PROJ-456|PROJ-456> — статус задачи
• делал code review по X
• kick-off по редизайну страницы артиста
• начал декомпозировать и считать стори-поинты для редизайна артиста
 
**24.04**
• отдать на ревью и в тестирование задачи по ренейму табов
• <https://jira.example.com/browse/PROJ-789|PROJ-789> — доделать оптимизацию размеров изображений
• Планирование спринта
```
 
---
 
## Formatting rules

**CRITICAL — Slack mrkdwn, not Markdown:**

The message is published in Slack. Slack uses its own mrkdwn syntax that **differs** from standard Markdown. Breaking the rules below = broken rendering for the whole team.

| Element | Correct | Incorrect |
|---|---|---|
| Bold (date) | `**30.04**` — two asterisks | ~~`*30.04*`~~ — one asterisk, renders as italic |
| Italic | `_текст_` | not used in standups |
| Bullet | `• ` (U+2022 + space) | ~~`- `~~ ~~`* `~~ |
| Jira link | `<https://...\|PROJ-XXXXX>` | ~~`https://...`~~ bare URL |
| Headers | do not use | ~~`## заголовок`~~ |
| Quotes / code blocks | do not use | ~~`> цитата`~~ ~~` ```блок``` `~~ |

> Note: date formatting rule updated 2026-05-05 — single asterisk rendered as italic in this team's Slack workspace; `**` gives bold.

**Required — blank line between blocks:**
Between the "yesterday" date and the "today" date — exactly one blank line (`\n\n`). Without it the blocks merge.

```
CORRECT:
**30.04**
• <https://jira.example.com/browse/PROJ-123|PROJ-123> — задеплоил фильтр

**01.05**
• <https://jira.example.com/browse/PROJ-456|PROJ-456> — деплойнуть

INCORRECT:
*30.04*               ← one asterisk: renders as italic
• ...
**01.05**             ← no blank line before next date
```

Other rules:
- Task description: brief, in your own words, past tense for "yesterday", future for "today/tomorrow"
- No commentary from Claude — only the message itself
- No trailing blank line at the end of the message
- **Bullet order with Jira key**: `• <KEY> — verb action`. Never put the verb before the link (`• завёл <KEY> — …` → wrong; `• <KEY> — завёл баг…` → correct).

---
 
## Input data

The skill receives data in two ways:

**A. Activity cards (preferred)** — when called from `standup-collect`
via `standup-aggregate`. Format:
```
## PROJ-XXXXX
- one_line: задеплоил фильтр переименованных табов
- closed_today: true
- prs: #2176 merged
- slack_dm_context: none
...

## no-key
- code_reviews: несколько код-ревью
- meetings: синк по статьям
```
Use the `one_line` field as the basis for the bullet. Supplement with context from other card fields as needed.

**B. Free-form user input** — voice or text. Apply the information-gathering algorithm in section 1 below.

---

## Drafting algorithm
 
### 1. Gather context
 
The user describes their day verbally or in text — often unstructured, with corrections and inexact task names. Extract the essence.
 
If the user provides a link to a previous Slack message — read it (`slack_read_thread`) to understand the format and style for that particular channel/team.
 
If the user says "look at Jira tasks" — search current sprint tasks assigned to the user (`assignee = currentUser() AND sprint in openSprints()`).
 
### 2. Message structure
 
The message has two blocks:
 
**Вчера (дата вчерашнего дня)**
— what was done during the past day
— each task as a separate bullet
— status: what was done, what remains ("осталось оформить и отдать в ревью", "осталось почистить код")
 
**Сегодня (дата текущего дня)**
— what is planned
— tasks and meetings as separate bullets
— meetings written without tickets ("Планирование спринта", "kick-off по X")
 
### 3. Jira tasks
 
- If the user mentions a ticket number — use it
- If the user describes a task without a number — try to find a match in the sprint by meaning
- Take the task wording from the user's description, not from the Jira ticket title (ticket titles are often in English and technical)
- Link format: `https://${STANDUP_ATLASSIAN_DOMAIN}/browse/${STANDUP_JIRA_PROJECT}-XXXXX` (resolve from config or context)

### 4. Common phrasing patterns
 
| Situation | Phrasing (RU example) |
|---|---|
| Task nearly done | "практически доделал X, осталось почистить код и отдать на ревью" |
| Task done, awaiting review | "доделал X, осталось оформить и отдать в ревью" |
| Task deployed | "задеплоил X" or "выпилил / задеплоил X" |
| Task in review | "отдать на ревью и в тестирование задачи по X" |
| Task handed to QA | "отдал в тестирование X, по одной из них есть что доработать" |
| Task with decision context | "X — сделали Y на беке, поэтому поддержал такое решение и отдал в ревью" |
| Task deployed with result | "задеплоил X — положительный результат на лицо, в задаче приложил метрику" |
| Incident / on-call | "фиксировал и отписывался об инцидентах инфры", "занёс в таблицу с инцидентами" |
| Deploy failed / infra | "пал деплой бекенда и post build фронтенда, занёс в таблицу с инцидентами" |
| Task not worked on | do not mention in "yesterday", put in "today" |
| Very little progress | "совсем немного продолжал с X" |
| Investigated / researched | "разбирался с недостающими типами X для экспа по Y" |
| New task entered sprint | "вылез запрос от X команды на Y, завёл задачу" |
| Many code reviews | "много code review" + topic if known |
| 1-on-1 meeting | "1-1 с [имя]" |
| Kick-off meeting | "kick-off по X" |
| Sync meeting | "синк по X" |
| Sprint planning | "Планирование спринта" |
| Research / estimation | "начал декомпозировать и считать стори-поинты для X" |
 
### 5. Slack and DM context

If the input includes Slack activity (incoming/outgoing DMs, channel messages), apply these rules:

1. **DM mentioning a sprint Jira key** → include the collaboration in that task's bullet.
2. **PR-review pings** → include as "несколько код-ревью" or "ревью по X" if topic is visible.
3. **Incoming DMs without a Jira key** → ignore, do not include in standup.
4. **Do not quote DMs verbatim** — paraphrase, third person.

### 7. Complex descriptions in one bullet
 
If multiple things were done on one task, or there is important context — describe everything in one bullet, separated by commas or a period.

---
 
## Key nuances (from real practice)
 
- **Colleague names** — short Russian forms: Саша (not Александр), Миша (not Михаил), Оля (not Ольга), Дима (not Дмитрий).
- **Collective voice** — if a discovery/decision was joint, use "обнаружили / решили / договорились". Otherwise first person.
- If the user says "I didn't work on that task yesterday" — remove from "yesterday", move to "today"
- If the user mentions "sync" or "meeting" — write only the essence ("kick-off", "синк"), without extra detail
- Specify code review topic when known
- Additional discoveries/blockers — include in "yesterday" as a separate bullet
- Meetings ("планирование спринта", "kick-off") — always in "today" if they are upcoming
- If a task has important decision context — include it, do not trim
- Infrastructure incidents — separate bullet without a ticket
- 1-on-1 meetings — separate bullet without a ticket: "1-1 с [имя]"
- If a "today" task is conditional — write it as-is

---
 
## Output format
 
Output only the ready message text — no explanations, no "here's your message:", no markdown code blocks. Just the text that can be copied and pasted into Slack.
