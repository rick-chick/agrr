#!/usr/bin/env bash
# Prepares agent-opt-in PRs for PR Merge Worker: agent-merge label + serial gh pr ready.
# See .github/workflows/pr-agent-prep.yml

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/pr-agent-prep-lib.mjs"

usage() {
  echo "Usage: $0 prep <pr_number>" >&2
  echo "       $0 advance-queue" >&2
  exit 2
}

node_eval() {
  node --input-type=module -e "$1"
}

configure_gh_auth() {
  local resolved
  resolved="$(AGRR_GH_PAT="${AGRR_GH_PAT:-}" GH_TOKEN="${GH_TOKEN:-}" GITHUB_TOKEN="${GITHUB_TOKEN:-}" node_eval "
    import { resolveGhToken } from '$LIB';
    process.stdout.write(resolveGhToken({
      agrrGhPat: process.env.AGRR_GH_PAT || null,
      ghToken: process.env.GH_TOKEN || null,
      githubToken: process.env.GITHUB_TOKEN || null,
    }));
  ")"
  if [ -n "$resolved" ]; then
    export GH_TOKEN="$resolved"
  fi
}

configure_gh_auth

repo_owner() {
  gh repo view --json owner -q .owner.login
}

fetch_pr_json() {
  local pr_number="$1"
  gh pr view "$pr_number" --json \
    number,isDraft,author,baseRefName,headRefName,body,labels,headRepository,closingIssuesReferences
}

pr_is_eligible() {
  local pr_json="$1"
  local base_owner="$2"
  PR_JSON="$pr_json" BASE_OWNER="$base_owner" node_eval "
    import { isEligibleAgentPr } from '$LIB';
    const pr = JSON.parse(process.env.PR_JSON);
    const labels = (pr.labels ?? []).map((l) => l.name);
    const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
    const eligible = isEligibleAgentPr({
      authorLogin: pr.author.login,
      baseRefName: pr.baseRefName,
      headRefName: pr.headRefName,
      body: pr.body,
      labels,
      headOwner,
      baseOwner: process.env.BASE_OWNER,
    });
    process.stdout.write(eligible ? 'true' : 'false');
  "
}

count_open_ready_agent_merge() {
  gh pr list --state open --label agent-merge --json isDraft \
    --jq '[.[] | select(.isDraft == false)] | length'
}

checks_are_green() {
  local pr_number="$1"
  local checks_json
  checks_json="$(gh pr checks "$pr_number" --json name,state 2>/dev/null || echo '[]')"
  CHECKS_JSON="$checks_json" node_eval "
    import { areRequiredChecksGreen } from '$LIB';
    const checks = JSON.parse(process.env.CHECKS_JSON);
    process.stdout.write(areRequiredChecksGreen(checks) ? 'true' : 'false');
  "
}

ensure_agent_no_merge_label() {
  local pr_number="$1"
  local labels
  labels="$(gh pr view "$pr_number" --json labels --jq '[.labels[].name] | join(",")')"
  if ! echo "$labels" | grep -qE '(^|,)agent-no-merge(,|$)'; then
    echo "Adding agent-no-merge label to PR #$pr_number (no linked issue for agent merge)"
    gh pr edit "$pr_number" --add-label agent-no-merge
  fi
}

ensure_agent_merge_label() {
  local pr_number="$1"
  local labels
  labels="$(gh pr view "$pr_number" --json labels --jq '[.labels[].name] | join(",")')"
  if ! echo "$labels" | grep -qE '(^|,)agent-merge(,|$)'; then
    echo "Adding agent-merge label to PR #$pr_number"
    gh pr edit "$pr_number" --add-label agent-merge
  fi
}

maybe_mark_ready() {
  local pr_number="$1"
  local pr_json is_draft open_ready checks_green can_ready

  pr_json="$(fetch_pr_json "$pr_number")"
  is_draft="$(echo "$pr_json" | jq -r '.isDraft')"
  if [ "$is_draft" != "true" ]; then
    echo "PR #$pr_number is already ready for review"
    return 0
  fi

  open_ready="$(count_open_ready_agent_merge)"
  checks_green="$(checks_are_green "$pr_number")"
  can_ready="$(PR_NUMBER="$pr_number" IS_DRAFT="$is_draft" OPEN_READY="$open_ready" CHECKS_GREEN="$checks_green" node_eval "
    import { canMarkReady } from '$LIB';
    const ok = canMarkReady({
      isDraft: process.env.IS_DRAFT === 'true',
      openReadyAgentMergeCount: Number(process.env.OPEN_READY),
      requiredChecksGreen: process.env.CHECKS_GREEN === 'true',
    });
    process.stdout.write(ok ? 'true' : 'false');
  ")"

  if [ "$can_ready" != "true" ]; then
    echo "PR #$pr_number not ready to mark ready (open_ready=$open_ready checks_green=$checks_green)"
    return 0
  fi

  echo "Marking PR #$pr_number ready for review"
  local ready_output ready_status=0
  ready_output="$(gh pr ready "$pr_number" 2>&1)" || ready_status=$?
  if [ "$ready_status" -ne 0 ]; then
    if [ -n "$ready_output" ]; then
      echo "$ready_output" >&2
    fi
    local non_fatal
    non_fatal="$(READY_ERR="$ready_output" node_eval "
      import { isNonFatalMarkReadyError } from '$LIB';
      process.stdout.write(isNonFatalMarkReadyError(process.env.READY_ERR) ? 'true' : 'false');
    ")"
    if [ "$non_fatal" = "true" ]; then
      echo "WARN: GITHUB_TOKEN cannot mark PR #$pr_number ready; will retry on next prep trigger"
      return 0
    fi
    return "$ready_status"
  fi
}

prep_pr() {
  local pr_number="$1"
  local pr_json eligible base_owner closing_issue_count should_merge

  base_owner="$(repo_owner)"
  pr_json="$(fetch_pr_json "$pr_number")"
  eligible="$(pr_is_eligible "$pr_json" "$base_owner")"
  if [ "$eligible" != "true" ]; then
    echo "PR #$pr_number is not eligible for agent prep; skipping"
    return 0
  fi

  closing_issue_count="$(echo "$pr_json" | jq '.closingIssuesReferences | length')"
  should_merge="$(PR_JSON="$pr_json" CLOSING_ISSUE_COUNT="$closing_issue_count" node_eval "
    import { shouldReceiveAgentMergeLabel } from '$LIB';
    const pr = JSON.parse(process.env.PR_JSON);
    const ok = shouldReceiveAgentMergeLabel({
      closingIssueCount: Number(process.env.CLOSING_ISSUE_COUNT),
      body: pr.body,
    });
    process.stdout.write(ok ? 'true' : 'false');
  ")"

  if [ "$should_merge" != "true" ]; then
    ensure_agent_no_merge_label "$pr_number"
    echo "PR #$pr_number has no linked issue; skipping agent-merge prep"
    return 0
  fi

  ensure_agent_merge_label "$pr_number"
  maybe_mark_ready "$pr_number"
}

advance_queue() {
  local open_ready drafts_json candidates_json base_owner pr_number is_draft

  base_owner="$(repo_owner)"
  open_ready="$(count_open_ready_agent_merge)"
  if [ "$open_ready" -gt 0 ]; then
    echo "Merge queue blocked by $open_ready ready agent-merge PR(s); skipping advance"
    return 0
  fi

  drafts_json="$(gh pr list --state open --label agent-merge --json number,isDraft,author,baseRefName,headRefName,body,labels,headRepository)"
  candidates_json="$(DRAFTS_JSON="$drafts_json" OPEN_READY="$open_ready" BASE_OWNER="$base_owner" node_eval "
    import { isEligibleAgentPr, sortedEligibleDraftNumbers } from '$LIB';
    const drafts = JSON.parse(process.env.DRAFTS_JSON).map((pr) => {
      const labels = (pr.labels ?? []).map((l) => l.name);
      const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
      return {
        number: pr.number,
        isDraft: pr.isDraft,
        eligible: isEligibleAgentPr({
          authorLogin: pr.author.login,
          baseRefName: pr.baseRefName,
          headRefName: pr.headRefName,
          body: pr.body,
          labels,
          headOwner,
          baseOwner: process.env.BASE_OWNER,
        }),
      };
    });
    process.stdout.write(JSON.stringify(sortedEligibleDraftNumbers(drafts, Number(process.env.OPEN_READY))));
  ")"

  if [ "$candidates_json" = "[]" ]; then
    echo "No eligible draft PR in agent-merge queue"
    return 0
  fi

  mapfile -t CANDIDATES < <(echo "$candidates_json" | jq -r '.[]')
  for pr_number in "${CANDIDATES[@]}"; do
    echo "Trying merge queue candidate PR #$pr_number"
    maybe_mark_ready "$pr_number"
    is_draft="$(gh pr view "$pr_number" --json isDraft -q .isDraft)"
    if [ "$is_draft" = "false" ]; then
      echo "Queue advanced to PR #$pr_number"
      return 0
    fi
  done

  echo "No eligible draft PR in agent-merge queue could be marked ready"
}

main() {
  local command="${1:-}"
  case "$command" in
    prep)
      [ "${2:-}" ] || usage
      prep_pr "$2"
      ;;
    advance-queue)
      advance_queue
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
