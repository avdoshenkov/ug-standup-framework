# Standup Log

Personal standup log repository. Powered by [ug-standup](https://github.com/avdoshenkov/ug-standup-framework).

## Usage

Open this directory in Claude Code and use:

- `/standup` — collect today's activity and draft the evening standup message (local mode)
- `/standup-cloud` — same but without local git repos (works in cloud Claude Code sessions)
- `/standup-archive` — backfill historical standup messages from Slack into `archive/`

## Directory structure

```
config/
  local.json    # per-user + team config (committed)
  state.json    # sprint cache + last run timestamp
logs/           # daily YYYY-MM-DD.json — raw collected activity
drafts/         # daily YYYY-MM-DD.md — unsent standup drafts
archive/        # published standup messages YYYY-MM-DD.md
```

## Config

Edit `config/local.json` to update your user identity, team identifiers,
or list of enabled sources.

For local-only secrets (Confluence token, local repo paths), copy `.env.example`
to `.env` and fill in the values. The `.env` file is gitignored and never committed.
