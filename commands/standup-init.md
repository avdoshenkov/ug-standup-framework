---
description: Bootstrap a new private standup data repository for a new user. Prompts for per-user and team config, creates the GitHub repo, and sets up local.json.
---

Run the init script interactively:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-data-repo.sh"
```

After the script completes, open the newly created data repo directory in
Claude Code and run `/standup` for the first dry run.
