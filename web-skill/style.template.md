# Personal Standup Style

Personal style overlay for the standup assistant.
Upload as a knowledge file named `style.md` in your Claude project (optional).
If omitted, the skill uses generic defaults.
Edit freely — changes take effect on the next run.

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
• <https://your-jira.atlassian.net/browse/PROJ-123|PROJ-123> — what you did
• <https://your-jira.atlassian.net/browse/PROJ-456|PROJ-456> — task status

**24.04**
• <https://your-jira.atlassian.net/browse/PROJ-789|PROJ-789> — planned work
• Sprint planning
-->

---

## Phrasing patterns

<!-- Optional. Table of situations → preferred phrasings. -->

<!--
| Situation | Preferred phrasing |
|---|---|
| Task done, awaiting review | "..." |
| Task deployed | "..." |
| Task handed to QA | "..." |
| Task in code review | "..." |
| Investigated / researched | "..." |
| Many code reviews | "..." |
| Sprint planning | "..." |
-->

---

## Stage wording

<!-- Optional. Maps Jira status → preferred standup verb.
     Prevents the skill from appending raw status labels. -->

<!--
| Jira status | Preferred verb / phrase |
|---|---|
| In Progress | "продолжил" |
| Code Review | "отдал в ревью" |
| Ready for QA | "отдал в тестирование" |
| In QA | "в тестировании" |
| Done | "выложил" |
-->

---

## Keywords

<!-- Optional. Keyword lists for classifying keyless activities. -->

<!--
meetings: sync, kick-off, 1-1, planning
incidents: down, deploy fail, incident, outage
code_reviews: LGTM, approved, reviewed
delegated: check this, look into, handle, investigate
-->
