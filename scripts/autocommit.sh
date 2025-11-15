#!/usr/bin/env bash
set -euo pipefail

# Auto-commit-on-save script
# Usage: run from workspace root or any subfolder. The script will cd to the repo root.
# WARNING: This will add, commit and push changes automatically. Use on feature branches only
# or adjust the script to skip `main`/`master` if you prefer.

cd "$(git rev-parse --show-toplevel)" || exit 1

# Configuration (can be overridden with env vars)
REMOTE=${AUTO_COMMIT_REMOTE:-origin}
# If AUTO_COMMIT_EXCLUDE_BRANCH is set (e.g. "main,master"), commits will be skipped on those branches
EXCLUDE_BRANCHES=${AUTO_COMMIT_EXCLUDE_BRANCH:-}

BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ -n "$EXCLUDE_BRANCHES" ]; then
  IFS=',' read -ra SKIP <<< "$EXCLUDE_BRANCHES"
  for b in "${SKIP[@]}"; do
    if [ "$b" = "$BRANCH" ]; then
      # skip auto-commit on this branch
      exit 0
    fi
  done
fi

# Only continue if there are unstaged/unstaged changes
if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

# Stage everything (you can narrow this if you want)
git add -A

# If nothing staged, exit
if git diff --cached --quiet; then
  exit 0
fi

MSG=${AUTO_COMMIT_MESSAGE:-"autosave: $(date +'%Y-%m-%d %H:%M:%S')"}

git commit -m "$MSG" || exit 0

# Push to the current branch on the configured remote
git push "$REMOTE" "$BRANCH"
