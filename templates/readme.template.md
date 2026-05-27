# Standup Log

Personal standup log repository. Powered by [ug-standup](https://github.com/avdoshenkov/ug-standup-framework).

## Usage

Open this directory in Claude Code and use:

- `/standup` — collect today's activity and draft the evening standup message
- `/standup-archive` — pull standup messages from Slack into `archive/` (run weekly)

Or type natural language: `"собери стендап"`, `"evening standup"`.

## Directory structure

```
config/
  local.json    # per-user + team config (committed)
  style.md      # personal phrasing style (optional, committed)
archive/        # published standup messages YYYY-MM-DD.md (populated by /standup-archive)
```

## Config

Edit `config/local.json` to update your user identity, team identifiers,
or optional sources (GitHub repos, Confluence).
