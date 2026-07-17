# Automation Authoring — 設計原則

## 二層分離

```
GitHub イベント
  → Actions（ゲート・ラベル・reconcile）
  → webhook
  → Cursor Cloud Agent（スキル・判断・PR）
  → GitHub 副作用
```

Cloud Agent はリポジトリを clone してスキルを読む。**ローカル Docker / ng serve は使えない**。

## ラベル契約

| 用途 | 正しい経路 | 誤った経路 |
|------|------------|------------|
| 依存未充足で待つ | `agent-ready` 維持 + dispatch 依存ゲート | `agent-skipped`（reconcile から除外） |
| 対応不要（オープン） | `agent-skipped` + 根拠コメント | 依存待ちと混同 |
| 着手中 | `agent-in-progress` | ラベルなしで webhook のみ |

`RETRY_BLOCK_LABELS`（`agent-skipped`, `agent-blocked`, `agent-in-progress`）に載るラベルを「一時保留」に使わない。

## ゲート

- 判定は `scripts/*-dispatch-lib.mjs` に集約する
- primary dispatch と retry dispatch で **同じ関数** を使う
- Worker SKILL 内の triage は **判断**（実装するか skip か）。機械ゲートの二重実装にしない

## retry / reconcile の標準形

| 要素 | 内容 |
|------|------|
| トリガー | `workflow_run: cancelled` **または `failure`**、15 分 cron、`workflow_dispatch` |
| 選定 | pure function、番号昇順、**1 回 1 件** |
| 送信 | `postWebhookJson`（500/502/503/429 は同一 run 内で backoff retry）+ `retry_reason` |
| concurrency | 固定 group、`cancel-in-progress: false` |

primary dispatch の webhook POST も `scripts/post-cursor-webhook.mjs`（`webhook-post-lib.mjs`）経由。恒久 4xx はジョブ失敗（無限ループにしない）。

## 本筋と救済の分離

| 層 | 目的 |
|----|------|
| **本筋** | 正しいラベル契約で primary + reconcile が回る |
| **救済** | 誤ラベル・レガシーデータの互換（例: deps 解消済み `agent-skipped` スキャン） |

救済層を足すときは **本筋を壊さない**こと。救済だけが唯一の経路にならないようにする。

## テスト

| 層 | 必須 |
|----|------|
| dispatch lib | `node --test scripts/*-dispatch-lib.test.mjs` |
| workflow 契約 | `verify-*-dispatch-workflow.test.mjs` |
| E2E | 実 issue/PR + Actions ログ + 副作用（[CHECKLIST.md](CHECKLIST.md)） |

unit test GREEN は E2E 完了の代替にならない。

## 監視

新規 dispatch workflow は `automation-pipeline-watchdog` の `DISPATCH_WORKFLOW_NAMES` に登録する。壊れたときに毎時検知できるようにする。
