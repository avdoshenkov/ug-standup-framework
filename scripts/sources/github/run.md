# GitHub source instructions

Run the shell helper to collect GitHub commits and PRs for `$DATE`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sources/github/lib/fetch.sh" "$DATE"
```

The helper reads `STANDUP_GH_ORG` and `STANDUP_GH_REPOS` from env.

Parse stdout as JSON. Expected shape:
```json
{
  "events": [
    {"type": "commit", "repo": "org/repo", "sha": "...", "message": "...", "url": "...", "at": "..."},
    {"type": "pr", "repo": "org/repo", "number": 123, "title": "...", "state": "...", "action": "merged", "url": "...", "at": "..."}
  ]
}
```

Store result under `sources.github` in `logs/<date>.json`. If `error` field is
present in output, store it as `sources.github.error` and continue.
