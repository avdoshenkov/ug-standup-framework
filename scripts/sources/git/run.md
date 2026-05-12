# Git (local) source instructions

Run the shell helper to collect local git repo activity for `$DATE`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sources/git/lib/fetch.sh" "$DATE"
```

The helper reads `STANDUP_LOCAL_REPOS` (colon-separated paths) from env.

Parse stdout as JSON. Expected shape:
```json
{
  "events": [
    {"type": "git_repo", "repo": "/path/to/repo", "branch": "main",
     "commits": [{"sha": "...", "message": "...", "at": "..."}],
     "uncommitted_changes": false, "unpushed_branches": []}
  ]
}
```

Store result under `sources.git` in `logs/<date>.json`. If `error` field is
present in output, store it as `sources.git.error` and continue.

Note: this source is `available_in: ["local"]` only. Cloud mode will record
`sources.git.skipped: "not available in cloud"` and continue.
