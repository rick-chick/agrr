#!/usr/bin/env bash
# Merge origin/master into a conflicting PR head branch using a temporary worktree.
# Does not use git checkout/switch on the caller's working tree.
#
# Usage: resolve-pr-merge-conflicts.sh <pr_number>
#
# Exit codes:
#   0 — merge completed and pushed (no remaining conflict markers)
#   1 — usage / git / gh error
#   2 — merge attempted but conflict markers remain (agent must resolve manually)
#   3 — PR is not in CONFLICTING state (no-op)
set -euo pipefail

PR_NUMBER="${1:-}"
if [ -z "$PR_NUMBER" ]; then
  echo "usage: resolve-pr-merge-conflicts.sh <pr_number>" >&2
  exit 1
fi

PR_JSON=$(gh pr view "$PR_NUMBER" --json headRefName,mergeable,mergeStateStatus,headRepositoryOwner,baseRepositoryOwner)
HEAD_REF=$(echo "$PR_JSON" | jq -r '.headRefName')
MERGEABLE=$(echo "$PR_JSON" | jq -r '.mergeable')
MERGE_STATE=$(echo "$PR_JSON" | jq -r '.mergeStateStatus')
HEAD_OWNER=$(echo "$PR_JSON" | jq -r '.headRepositoryOwner.login')
BASE_OWNER=$(echo "$PR_JSON" | jq -r '.baseRepositoryOwner.login')

if [ "$HEAD_OWNER" != "$BASE_OWNER" ]; then
  echo "fork PR is not supported" >&2
  exit 1
fi

if [ "$MERGEABLE" != "CONFLICTING" ] && [ "$MERGE_STATE" != "DIRTY" ]; then
  echo "PR #$PR_NUMBER is not conflicting (mergeable=$MERGEABLE mergeStateStatus=$MERGE_STATE)"
  exit 3
fi

WORKDIR=$(mktemp -d)
cleanup() {
  git worktree remove --force "$WORKDIR" 2>/dev/null || rm -rf "$WORKDIR"
}
trap cleanup EXIT

git fetch origin master "$HEAD_REF"
git worktree add --detach "$WORKDIR" "origin/$HEAD_REF"
cd "$WORKDIR"

set +e
git merge origin/master --no-edit
MERGE_EXIT=$?
set -e

CONFLICT_FILES=$(git diff --name-only --diff-filter=U || true)
if [ -n "$CONFLICT_FILES" ]; then
  echo "CONFLICT_FILES:"
  printf '%s\n' "$CONFLICT_FILES"
  exit 2
fi

if [ "$MERGE_EXIT" -ne 0 ]; then
  echo "git merge failed without listed conflict files (exit=$MERGE_EXIT)" >&2
  exit 1
fi

git push origin "HEAD:$HEAD_REF"
echo "Merged origin/master into $HEAD_REF for PR #$PR_NUMBER"
