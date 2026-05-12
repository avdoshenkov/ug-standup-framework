# Changelog

## [0.1.0] — 2026-05-12

Initial release.

### Added

- `/standup` command — local-mode collection via `standup-collect` skill
- `/standup-cloud` command — cloud-mode collection via `standup-collect-cloud` skill
- `/standup-archive` command — Slack backfill via `standup-backfill` skill
- `/standup-init` command — new user onboarding via `init-data-repo.sh`
- Pluggable sources architecture — `source.json` + `run.md` per source
- Built-in sources: `jira` (shell), `github` (shell), `git` (shell, local-only), `slack-self` (mcp)
- Stub sources: `slack-channels`, `confluence-cloud`, `confluence-self-hosted`
- `scripts/lib/config.sh` — config merge helper (team-defaults ← local.json ← .env)
- `config/team-defaults.json` — schema-only placeholders (public repo safe)
- Templates for data repo bootstrapping
