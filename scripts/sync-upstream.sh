#!/usr/bin/env bash
set -euo pipefail

# sync-upstream — cherry-pick upstream pi-mono commits touching feature packages
# Run from hull/ root.
# Usage: ./scripts/sync-upstream.sh

UPSTREAM_REMOTE="${UPSTREAM_REMOTE:-upstream}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"

# Feature packages — everything except ai/agent (those live in keel)
FEATURE_PKGS=("packages/coding-agent" "packages/tui" "packages/web-ui")

# Verify upstream remote points to badlogic/pi-mono
URL=$(git remote get-url "$UPSTREAM_REMOTE" 2>/dev/null || echo "")
if [[ -z "$URL" ]]; then
  echo "Error: remote '$UPSTREAM_REMOTE' not found" >&2
  echo "Add upstream: git remote add upstream https://github.com/badlogic/pi-mono.git" >&2
  exit 1
fi
if ! grep -q "badlogic/pi-mono" <<< "$URL"; then
  echo "Error: upstream remote does not point to badlogic/pi-mono" >&2
  echo "Current URL: $URL" >&2
  exit 1
fi

# Verify clean working tree
dirty=$(git status --porcelain)
if [[ -n "$dirty" ]]; then
  echo "Error: working tree is dirty" >&2
  echo "$dirty" >&2
  exit 1
fi

# Verify not on main (avoid mutating production branch directly)
current=$(git branch --show-current)
if [[ "$current" == "$UPSTREAM_BRANCH" ]]; then
  echo "Error: refusing to run on $UPSTREAM_BRANCH branch" >&2
  echo "Run from a feature branch or pass --force to override" >&2
  exit 1
fi

git fetch "$UPSTREAM_REMOTE"

LAST_SYNC=$(git rev-parse refs/heads/sync-marker 2>/dev/null || git merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")
COMMITS=$(git log --reverse --format="%H" "$LAST_SYNC..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" 2>/dev/null || echo "")

if [[ -z "$COMMITS" ]]; then
  echo "Up to date."
  exit 0
fi

APPLIED=0
SKIPPED=0
MANUAL=()

for commit in $COMMITS; do
  FILES=$(git diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null || echo "")
  MSG=$(git log --format="%s" -1 "$commit" 2>/dev/null)

  TOUCHES_FEATURES=false
  TOUCHES_HARNESS=false

  for f in $FILES; do
    matched=false
    for pkg in "${FEATURE_PKGS[@]}"; do
      [[ "$f" == "$pkg"/* || "$f" == "$pkg" ]] && matched=true
    done
    if $matched; then
      TOUCHES_FEATURES=true
    else
      TOUCHES_HARNESS=true
    fi
  done

  if $TOUCHES_FEATURES && ! $TOUCHES_HARNESS; then
    echo "[$commit] APPLY : $MSG"
    git cherry-pick "$commit" --strategy-option=theirs 2>&1 || {
      echo "CONFLICT — aborting cherry-pick"
      MANUAL+=("CONFLICT:$commit:$MSG")
      git cherry-pick --abort 2>/dev/null || true
    }
    ((APPLIED++)) || true
  elif $TOUCHES_FEATURES && $TOUCHES_HARNESS; then
    echo "[$commit] MANUAL: $MSG (touches features + harness)"
    MANUAL+=("CROSS:$commit:$MSG")
  else
    echo "[$commit] SKIP  : $MSG (harness-only — belongs in keel)"
    ((SKIPPED++)) || true
  fi
done

git branch -f sync-marker "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

echo ""
echo "Applied: $APPLIED  Skipped: $SKIPPED  Manual: ${#MANUAL[@]}"
for entry in "${MANUAL[@]}"; do
  echo "  $entry"
done
