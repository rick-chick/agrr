---
name: delivery-agent
description: >-
  rick-chick/agrr の Delivery Agent: issue 起票から squash merge まで 1 Automation で完遂。
  webhook は repository + issue_number / pr_number のみ（action なし）。GitHub 状態を観測して判断する。
---

# Delivery Agent（AGRR）

**1 run = 1 件**（issue または PR）。人間待ちなし。

正本の手順は本 SKILL の **§0 観測と分岐**。実装・マージの詳細は参照スキルを読む。

| 参照スキル | 用途 |
|-----------|------|
| [`github-issue-worker/SKILL.md`](../github-issue-worker/SKILL.md) | triage・実装・close・epic |
| [`github-pr-merge-worker/SKILL.md`](../github-pr-merge-worker/SKILL.md) | コンフリクト解消・CI 修正・merge |
| [`tdd-on-edit/SKILL.md`](../tdd-on-edit/SKILL.md) | 改修 TDD |
| [`test-common/SKILL.md`](../test-common/SKILL.md) | テスト実行 |

参照スキル内の **`action` 条件はレガシー**。§0 の観測結果が常に優先する。payload に `action` があっても**無視**する。

## §0 観測と分岐（毎 run 先頭・固定順）

1. **payload** — `repository`、任意の `issue_number` / `pr_number`
   - **`body_hash` あり** → 依存判定 run のみ（§依存）。実装・PR 禁止。終了。
2. **番号解決** — `pr_number` のみなら `gh pr view` → 本文 `Closes #N` / `fixes #N` で issue を特定
3. **in-progress** — `agent-in-progress` または `agent-merge-in-progress` が付いていれば **即終了**（コメント不要）
4. **open PR** — `Closes #N` / `fixes #N` の open PR を検索
   - **あり** → PR フェーズ（[`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md)）: CI / mergeable / Draft を見て修正・merge・待ち
   - **なし** → issue フェーズ（[`github-issue-worker`](../github-issue-worker/SKILL.md)）: triage → 実装 or close or 依存待ち
5. **epic** — `[epic]` / `epic` ラベルなら §1b（子 issue 完了確認 → close）

### PR フェーズでやらないこと

- 新規 issue 実装
- 同一 issue に **2 つ目の PR** を開く

### issue フェーズでやらないこと

- squash merge（ready 化は **prep** 機械。Agent は `gh pr ready` しない）

## Webhook payload

```json
{
  "repository": "rick-chick/agrr",
  "issue_number": 323,
  "pr_number": 427
}
```

| フィールド | 必須 |
|-----------|------|
| `repository` | はい |
| `issue_number` | issue 起点時 |
| `pr_number` | PR / CI 起点時（`issue_number` は PR 本文から解決可） |
| `action` | **送らない・無視** |

任意: `issue_title`, `issue_url`, `issue_body`, `labels`, `pr_title`, `pr_url`, `retry_reason`, `body_hash`（依存判定 run のみ）

## 依存

`## 依存` 節がある issue は **`agent-deps:v1` コメントキャッシュのみ**を根拠にする。本文 `#N` パース禁止。

### `body_hash` 付き payload（依存判定 run）

[`issue-worker-deps-resolve.mjs`](../../../scripts/issue-worker-deps-resolve.mjs) がキャッシュ miss 時に送る。**この run の唯一の仕事**は `agent-deps:v1` コメント作成。実装・PR・マージは禁止。完了したら終了（implement dispatch は reconcile が後続）。

## Automation（Cursor Dashboard）

| 項目 | 値 |
|------|-----|
| トリガー | **Webhook のみ** |
| 付けない | CI completed、Pull request opened（二重起動の元） |
| PR 作成 | ON |
| Memories | ON |

```
Read `.cursor/skills/delivery-agent/SKILL.md` exactly.
Payload: repository, issue_number, pr_number (optional).
No action field — if present, ignore it. Observe GitHub state and decide.
Use referenced skills for implement and merge paths.
```

**Secrets**: `CURSOR_DELIVERY_WEBHOOK_URL` / `CURSOR_DELIVERY_WEBHOOK_KEY`

## 切替（運用）

1. Delivery Automation 作成（Webhook のみ）
2. secrets 確認
3. 旧 Issue / Merge / Deps Automation を **OFF**
4. dispatch workflow マージ（本リポジトリ）
5. スモーク: `workflow_dispatch` on retry workflows

ロールバック: 旧 Automation ON + secrets を旧 URL に戻す + dispatch revert。
