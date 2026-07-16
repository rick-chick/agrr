#!/usr/bin/env bash
# Verify automation-critical skill files and scripts exist (not just SKILL.md stubs).
# Used by cloud-automation-audit §1C. Exit 0 = all present, 1 = any missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
cd "$ROOT"

missing=0

require() {
  local path="$1"
  if [ ! -e "$path" ]; then
    echo "MISSING: $path" >&2
    missing=1
  fi
}

# Automation entry skills
require .cursor/skills/github-issue-worker/SKILL.md
require .cursor/skills/github-pr-merge-worker/SKILL.md
require .cursor/skills/ux-issue-pipeline/SKILL.md
require .cursor/skills/sequential-cleanup-review-workflow/SKILL.md
require .cursor/skills/cloud-automation-audit/SKILL.md
require .cursor/skills/automation-pipeline-watchdog/SKILL.md
require .cursor/environment.json
require .cursor/scripts/cloud-gh-auth.sh

# Issue Worker §2 routing (core)
for skill in tdd-on-edit error-investigation error-fix-red-green test-common test-slow-detection \
  i18n-completion-workflow clean-architecture-violation-fix-workflow process-monitor; do
  require ".cursor/skills/${skill}/SKILL.md"
done

# sequential-cleanup §4 entry + outer loop
require .cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh
require .cursor/skills/sequential-cleanup-review-workflow/scripts/run-outer-loop.sh
for ref in STARTUP DUAL_LOOP AGENT_ORCHESTRATION MECHANICAL_OUTER_LOOP STEPS_ABCD RULES SCRIPTS CHECKLIST; do
  require ".cursor/skills/sequential-cleanup-review-workflow/references/${ref}.md"
done

# CA workflow chain (ARCHITECTURE.md / github-issue-worker)
require .cursor/skills/clean-architecture-violation-fix-workflow/references/agent-operational-canonical.md
require .cursor/skills/clean-architecture-goal-statement/SKILL.md

# test-common scripts (Issue Worker §3)
require .cursor/skills/test-common/scripts/run-test-frontend.sh
require .cursor/skills/test-common/scripts/run-test-rust-domain.sh

# CLAUDE.md always-applied rules
for rule in agent-conventions dont-finish-task-while-process-is-running \
  evidence-before-design-and-implementation user-request-project-alignment gcp-available \
  implementation-consistency-with-existing no-convenience-tech-debt project-necessary-code-only \
  rails-clean-architecture git-operational-constraints tdd-on-edit docker-dev-agrr-server-rebuild \
  ca-violation-fix-architecture-gate use-skills-on-edit; do
  require ".cursor/rules/${rule}.mdc"
done

# GitHub workflows that call skill scripts
require .github/workflows/issue-worker-dispatch.yml
require .github/workflows/cleanup-outer-loop-dispatch.yml

if [ "$missing" -ne 0 ]; then
  echo "verify-skill-references: one or more paths missing" >&2
  exit 1
fi

echo "verify-skill-references: OK"
