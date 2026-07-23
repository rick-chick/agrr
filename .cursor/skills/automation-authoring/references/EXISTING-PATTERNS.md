# 読むべき既存経路

新規 dispatch / retry を足す前に、同型の **動いている実装** を読む。

設計時は [PRINCIPLES.md §目的](PRINCIPLES.md)（人間介在なしで完遂・既定は対象）と [automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc) を先に読む。

## Issue 実装パイプライン

| 読むファイル | 内容 |
|--------------|------|
| `.github/workflows/issue-worker-dispatch.yml` | primary dispatch・ゲート・webhook |
| `.github/workflows/issue-worker-retry-dispatch.yml` | cancelled / cron / closed retry |
| `scripts/issue-worker-dispatch-lib.mjs` | ゲート・候補選定（pure） |
| `scripts/issue-worker-dispatch-lib.mjs` | Issue Worker 構造ゲート・reconcile 選定（依存判断なし） |
| `scripts/issue-worker-retry-dispatch.mjs` | reconcile・`postWebhook` |
| `scripts/verify-issue-worker-dispatch-workflow-lib.mjs` | workflow 契約 |
| `.cursor/skills/github-issue-worker/SKILL.md` | Agent 側手順 |

**retry は `postWebhook` 直接**。`agent-ready` reconcile と同型。

## PR マージパイプライン

| 読むファイル | 内容 |
|--------------|------|
| `.github/workflows/pr-merge-worker-dispatch.yml` | CI 完了・コンフリクト検知 → webhook 中継（**全 PR 既定対象・オプトアウトのみ**） |
| `.github/workflows/pr-merge-worker-retry-dispatch.yml` | reconcile（open + base master への webhook 再送） |
| `.github/workflows/pr-agent-prep.yml` | Draft → ready（`closingIssuesReferences` あり → `agent-merge` + `gh pr ready`。未リンクはスキップ・ラベルなし） |
| `scripts/delivery-dispatch-lib.mjs` | Delivery webhook payload（`repository` + `issue_number` / `pr_number`。`action` なし） |
| `scripts/pr-merge-worker-retry-dispatch-lib.mjs` | 候補選定（重複抑止・構造除外のみ。webhook は同一形） |
| `scripts/pr-merge-worker-retry-dispatch.mjs` | reconcile・webhook 再送 |
| `.cursor/skills/github-pr-merge-worker/SKILL.md` | Agent 側 |

## 監視・監査

| 読むファイル | 内容 |
|--------------|------|
| `.cursor/skills/automation-pipeline-watchdog/SKILL.md` | 毎時監視・起票 |
| `.cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health-lib.mjs` | 閾値・finding |
| `.cursor/skills/cloud-automation-audit/SKILL.md` | 週次監査 |

## 俯瞰・運用正本

| 読むファイル | 内容 |
|--------------|------|
| `docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md` | アーキテクチャ |
| `.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md` | cron / secrets |
