# Personal Standup Style

Personal style overlay for the standup assistant.
Loaded by `standup-format` and `standup-aggregate` at runtime.
Edit freely — changes take effect on the next run.
Lines with `<!-- ... -->` are guidance; fill in or delete.

---

## Language

<!-- Required. Tell the model what language to write in. -->

Output language: <!-- e.g. Russian / English -->

---

## Reference example

<!-- Optional but strongly recommended.
     Paste one real standup message that represents your ideal output.
     The model uses it as a style anchor. -->

<!--
**23.04**
• <https://your-jira.example.com/browse/PROJ-123|PROJ-123> — what you did, what remains
• <https://your-jira.example.com/browse/PROJ-456|PROJ-456> — task status

**24.04**
• <https://your-jira.example.com/browse/PROJ-789|PROJ-789> — planned work
• Sprint planning
-->

---

## Phrasing patterns

<!-- Optional. Table of situations → preferred phrasings. -->

<!--
| Situation | Preferred phrasing |
|---|---|
| Task nearly done | "..." |
| Task done, awaiting review | "..." |
| Task deployed | "..." |
| Task in code review | "..." |
| Task handed to QA | "..." |
| Low progress | "..." |
| Investigated / researched | "..." |
| New task entered sprint | "..." |
| Many code reviews | "..." |
| 1-on-1 meeting | "..." |
| Kick-off meeting | "..." |
| Sync meeting | "..." |
| Sprint planning | "..." |
| Research / estimation | "..." |
-->

---

## Names

<!-- Optional. Preferred short forms for frequent collaborators. -->

<!--
- Full name / Slack display name → preferred short form
- Example: Alexander Petrov → Саша
-->

---

## Stage wording

<!-- Optional. Maps Jira status → preferred standup verb. -->

<!--
| Jira status | Preferred verb / phrase |
|---|---|
| In Progress | "..." |
| Code Review | "..." |
| Ready for QA | "..." |
| In QA | "..." |
| Done | "..." |
-->

---

## Keywords

<!-- Optional. Keyword lists for standup-aggregate to classify keyless activities. -->

<!--
### Meetings
meetings: sync, kick-off, 1-1, planning

### Incidents
incidents: down, deploy fail, incident, outage

### Code review markers
code_reviews: LGTM, approved, reviewed

### Delegation triggers
delegated: check this, look into, handle, investigate
-->
