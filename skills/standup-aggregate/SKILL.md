---
name: standup-aggregate
description: Cross-source aggregator for standup evidence. Takes log JSON + Slack dump, produces per-issue activity cards for the standup-format skill. Called as a subagent from standup-collect Step 3.5.
---

# Standup Aggregate

Cross-source aggregator. Takes noisy raw data (log JSON + Slack dump) and
produces structured **activity cards** — one per Jira key, plus a tail for
keyless activity. The `standup-format` skill formats from these cards.

---

## Input (from calling skill)

Two data blobs passed in the prompt:

1. **Log JSON** — the `logs/YYYY-MM-DD.json` object (or virtual log in cloud
   mode). Shape:
   ```json
   {
     "sources": {
       "jira": {"events": [...]},
       "github": {"events": [...]},
       "git": {"events": [...]}
     }
   }
   ```
2. **Slack dump** — combined messages from searches:
   - Outbound (`from:me`): messages I sent in public channels.
   - Inbound DMs (`to:me`): messages I received in DMs.
   - PR pings: bot messages about review requests.

---

## Output format

Return only the activity cards — no preamble, no coda. One markdown block
per Jira key, then the keyless tail.

### Per-key card

```
## PROJ-XXXXX
- summary: <Jira issue summary, one phrase>
- status: <current Jira status>
- closed_today: <true|false>
- status_changes: <list or "none">
- my_jira_comments: <count>
- prs: <list of #number + action, or "none">
- commits: <count and repos, or "none">
- slack_outbound_mentions: <count in public channels>
- slack_dm_context: <one sentence on DM content if relevant, or "none">
- one_line: <suggested standup bullet body in Russian, first person past tense>
```

### Keyless tail

```
## no-key
- code_reviews: <count of PRs reviewed (not authored), list of themes if clear>
- meetings: <list of syncs/kick-offs/1-1s found in outbound Slack, or "none">
- incidents: <any infra/deploy failures mentioned, or "none">
- delegated_tasks: <list of "завёл задачу [name]: [topic]" if applicable, or "none">
- escalations: <user-initiated investigation threads with ≥3 replies, or "none">
```

---

## Aggregation rules

### 1. Build the key universe

Collect all Jira keys mentioned in any source (regex `[A-Z]+-\d+`):
- `sources.jira.events[].key`
- PR titles matching the Jira key pattern
- Commit messages matching the Jira key pattern
- Outbound Slack messages matching the Jira key pattern
- Inbound DMs matching the Jira key pattern

Deduplicate. Sprint tasks that appear in no source → omit (not touched today).

### 2. Per-key: populate fields

- **status / closed_today**: from `sources.jira` entry for this key.
- **my_jira_comments**: count of `comments_by_me` entries for this key.
- **status_changes**: humanise status change array: `"К выполнению → Готово"`.
- **prs**: authored PRs in `sources.github.events` with matching key in title.
  Include state: `#2176 merged`, `#2192 open`, `#2028 closed`.
- **commits**: count of commits matching the key in message across all git sources.
- **slack_outbound_mentions**: count of outbound messages (from:me) containing this key.
- **slack_dm_context**: if an inbound DM mentions this key, summarise in ≤10 words Russian. If no DM → "none".
- **one_line**: synthesise a single Russian standup bullet body. Rules:
  - Past tense ("задеплоил", "отдал в QA", "разобрался с").
  - If `closed_today = true`: lead with "задеплоил" or "закрыл" depending on PR state.
  - If PR merged: include "замержен PR" or "задеплоил".
  - If `comments_by_me > 0` and no PR: include action from comment context.
  - If `slack_dm_context` reveals collaboration: append it after "—".
  - Keep ≤12 words.
  - **Stage wording from Jira status**: `Ready for QA` / `In QA` → "отдал в тестирование"; `Code Review` / open PR, no QA transition → "отдал на ревью"; `Готово` / `Done` + merged PR → "задеплоил".

### 3. Keyless tail

- **code_reviews**: count outbound replies containing a PR link or "LGTM"/"approved"/"посмотрел". Fall back to reviewed PRs from github source. If ≥2, write "несколько код-ревью". If recognisable themes, add them.
- **meetings**: scan outbound Slack for words "синк", "kick-off", "1-1", "планирование", "встреч". List each as a short phrase.
- **incidents**: scan outbound Slack for "упал", "деплой", "инцидент", "таблицу инцидентов". If found, one line.
- **delegated_tasks**: scan outbound Slack (public channels, not DMs) for messages with a `<@USER_ID>` mention AND at least one of: (`поисследуй`, `посмотри`, `разберись`, `проверь`, a Sentry URL, or a Jira URL for a key **not** in the current key universe). Format: `завёл задачу [name]: [≤5 words topic]`. If none → "none".
- **escalations**: scan outbound Slack for user-initiated threads with `reply_count ≥ 3` that open with a question or request for help. If found, one line summary. If none → "none".

### 4. Filtering inbound DMs (broad → narrow)

All inbound DMs arrived since `since`. Filter:
- Keep only DMs that contain a Jira key from the key universe OR contain names of collaborators found in PR reviews/comments.
- Discard personal chatter with no sprint relevance.
- For kept DMs, read the surrounding thread via `slack_read_thread` (cap: 5 threads max) to get context for `slack_dm_context`.

---

## Do NOT

- Do NOT format the final standup message — that is `standup-format`'s job.
- Do NOT include raw Slack message bodies verbatim in the cards.
- Do NOT include sprint tasks that have zero activity across all sources.
- Do NOT add cards for keys that only appear in sprint tasks but had no updates since `since`.
