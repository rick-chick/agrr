# 読むべき既存経路

新規 dispatch / retry を足す前に、同型の **動いている実装** を読む。

設計時は [PRINCIPLES.md §目的](PRINCIPLES.md)（人間介在なしで完遂・既定は対象）を先に読む。

## Issue 実装パイプライン

| 読むファイル | 内容 |
|--------------|------|
| `.github/workflows/issue-worker-dispatch.yml` | primary dispatch・ゲート・webhook |
| `.github/workflows/issue-worker-retry-dispatch.yml` | cancelled / cron / closed retry |
| `scripts/issue-worker-dispatch-lib.mjs` | ゲート・候補選定（pure） |
| `scripts/issue-worker-deps-agent-lib.mjs` | `agent-deps:v1` キャッシュ契約（本文 `#N` パースなし） |
| `scripts/issue-worker-deps-resolve.mjs` | キャッシュ miss 時の deps Agent webhook |
| `scripts/issue-worker-retry-dispatch.mjs` | reconcile・`postWebhook` |
| `scripts/verify-issue-worker-dispatch-workflow-lib.mjs` | workflow 契約 |
| `.cursor/skills/github-issue-worker/SKILL.md` | Agent 側手順 |

**retry は `postWebhook` 直接**。`agent-ready` reconcile と同型。

## PR マージパイプライン

| 読むファイル | 内容 |
|--------------|------|
| `.github/workflows/pr-merge-worker-dispatch.yml` | CI / conflict / ci_fix（**全 PR 既定対象・オプトアウトのみ**） |
| `.github/workflows/pr-merge-worker-retry-dispatch.yml` | reconcile（open + base master 全件） |
| `.github/workflows/pr-agent-prep.yml` | Draft → ready（AI 不要） |
| `scripts/pr-merge-worker-retry-dispatch-lib.mjs` | 候補選定 |
| `.cursor/skills/github-pr-merge-worker/SKILL.md` | Agent 側 |

## 監視・監査

| 読むファイル | 内容 |
|--------------|------|
| `.cursor/skills/automation-pipeline-watchdog/SKILL.md` | 毎時監視・起票 |
| `scripts/collect-pipeline-health-lib.mjs` | 閾値・finding |
| `.cursor/skills/cloud-automation-audit/SKILL.md` | 週次監査 |

## 俯瞰・運用正本

| 読むファイル | 内容 |
|--------------|------|
| `docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md` | アーキテクチャ |
| `.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md` | cron / secrets |
