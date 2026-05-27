# Changelog

## [0.2.0] — 2026-05-27

### Breaking changes

- **Collapsed three collect skills to one.** `standup-collect-web` is now the single
  canonical `standup-collect`. The old `standup-collect` (local/shell) and
  `standup-collect-cloud` (cloud/shell) are removed. The `/standup-cloud` command is
  removed. Use `/standup` on all surfaces.
- **Ephemeral model.** The daily skill no longer writes any files — no `logs/`, no
  `drafts/`, no `state.json`, no `archive/`. `since` is resolved from the last Slack
  post; sprint is fetched fresh each run.
- **No `data_repo` or `state.json`.** GitHub-based persistence is removed. Archive is
  now a separate, decoupled job.
- **`enabled_sources` removed from config.** Sources are now tool-gated (active if the
  tool is reachable) and opt-in via `confluence.enabled`.

### Added

- Optional **Confluence source** (Step 5.5) — set `confluence.enabled: true` in config.
  Works with Cloud Confluence via Atlassian/Rovo or self-hosted via `mcp-atlassian`.

### Changed

- `standup-backfill` (formerly a one-time history importer) reframed as a **periodic
  archive-sync job** — run weekly to pull finalized standups from Slack into
  `archive/YYYY-MM-DD.md`. Config is now read via the Read tool instead of `config.sh`.
- `init-data-repo.sh` no longer creates `logs/`, `drafts/`, or `state.json`. Only
  `config/` and `archive/` are scaffolded.
- `web-template/config.template.md` adds `confluence.enabled` block; removes
  `data_repo` and `github_branch`.

### Removed

- `scripts/collect-standup.sh` — shell orchestrator
- `scripts/sources/` — shell source system (`jira`, `github`, `git`, `slack-*`, `confluence-*`)
- `scripts/lib/config.sh` — config merge helper
- `scripts/backfill-archive.sh` — replaced by `standup-backfill` skill step 0 reading JSON directly
- `config/team-defaults.json` — consumed only by the deleted `config.sh`
- `skills/standup-collect/` (old local) and `skills/standup-collect-cloud/`

---

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
