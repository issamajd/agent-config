#!/usr/bin/env bash
# sync.sh - pull the latest agent-config and re-run install.sh.
# Fast-forward only: a conflict fails loudly instead of merging.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$REPO"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "sync: uncommitted changes in $REPO, skipping pull" >&2
else
  git pull --ff-only --quiet
fi
git submodule update --init --recursive --quiet

exec "$REPO/install.sh"
