#!/usr/bin/env bash
# Merge origin/master into a PR head when BEHIND, CONFLICTING, or DIRTY.
# Uses a temporary worktree; does not use git checkout/switch on the caller's tree.
#
# Usage: resolve-pr-merge-conflicts.sh <pr_number>
#
# Exit codes:
#   0 — merge completed and pushed (no remaining conflict markers)
#   1 — usage / git / gh error
#   2 — merge attempted but conflict markers remain (agent must resolve manually)
#   3 — PR does not need master sync (no-op)
set -euo pipefail

PR_NUMBER="${1:-}"
if [ -z "$PR_NUMBER" ]; then
  echo "usage: resolve-pr-merge-conflicts.sh <pr_number>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
NEEDS_SYNC_LIB="$REPO_ROOT/scripts/pr-merge-worker-needs-sync.mjs"

PR_JSON=$(gh pr view "$PR_NUMBER" --json headRefName,mergeable,mergeStateStatus,isCrossRepository)
HEAD_REF=$(echo "$PR_JSON" | jq -r '.headRefName')
MERGEABLE=$(echo "$PR_JSON" | jq -r '.mergeable')
MERGE_STATE=$(echo "$PR_JSON" | jq -r '.mergeStateStatus')
IS_CROSS_REPO=$(echo "$PR_JSON" | jq -r '.isCrossRepository')

if [ "$IS_CROSS_REPO" = "true" ]; then
  echo "fork PR is not supported" >&2
  exit 1
fi

needs_sync="$(MERGEABLE="$MERGEABLE" MERGE_STATE="$MERGE_STATE" node --input-type=module -e "
  import { prMergeWorkerNeedsSync } from '$NEEDS_SYNC_LIB';
  const ok = prMergeWorkerNeedsSync({
    mergeable: process.env.MERGEABLE,
    mergeStateStatus: process.env.MERGE_STATE,
  });
  process.stdout.write(ok ? 'true' : 'false');
")"

if [ "$needs_sync" != "true" ]; then
  echo "PR #$PR_NUMBER does not need master sync (mergeable=$MERGEABLE mergeStateStatus=$MERGE_STATE)"
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
echo "Merged origin/master into $HEAD_REF for PR #$PR_NUMBER (mergeStateStatus=$MERGE_STATE)"
