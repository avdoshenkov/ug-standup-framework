#!/usr/bin/env bash
# Rebuild standup-web.zip from web-skill/standup-web/SKILL.md.
# Run after editing SKILL.md, then re-upload to claude.ai Customize → Skills.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_SKILL_DIR="$REPO_ROOT/web-skill"
ZIP_NAME="standup-web.zip"

cd "$WEB_SKILL_DIR"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" standup-web/
echo "Built: $WEB_SKILL_DIR/$ZIP_NAME"
unzip -l "$ZIP_NAME"
