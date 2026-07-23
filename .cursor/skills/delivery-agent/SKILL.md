---
name: delivery-agent
description: >-
  rick-chick/agrr の Delivery Agent: issue 起票から squash merge まで 1 Automation で完遂。
  webhook は repository + issue_number / pr_number のみ（action なし）。GitHub 状態を観測して判断する。
---

# Delivery Agent（AGRR）

**1 run = 1 件**（issue または PR）。**例外**: 同一 run 内の UX キャンペーン post-merge（§PR マージ成功後）のみ、マージした PR に続けて実施する。

**判断基準（正本）**: [JUDGMENT-CRITERIA.md](../automation-authoring/references/JUDGMENT-CRITERIA.md) — 迷ったら先に読む。

正本の手順は本 SKILL の **§0 観測と分岐**。実装・マージの詳細は参照スキルを読む。

| 参照スキル | 用途 |
|-----------|------|
| [`github-issue-worker/SKILL.md`](../github-issue-worker/SKILL.md) | triage・実装・close・epic |
| [`github-pr-merge-worker/SKILL.md`](../github-pr-merge-worker/SKILL.md) | コンフリクト解消・CI 修正・merge |
| [`ux-campaign-loop/SKILL.md`](../ux-campaign-loop/SKILL.md) | PR マージ成功後のキャンペーン post-merge（scan・残件起票・完了） |
| [`sequential-cleanup-review-workflow/SKILL.md`](../sequential-cleanup-review-workflow/SKILL.md) | TDD GREEN 後の順次クリーンアップ・レビュー（§4 必須） |
| [`tdd-on-edit/SKILL.md`](../tdd-on-edit/SKILL.md) | 改修 TDD |
| [`test-common/SKILL.md`](../test-common/SKILL.md) | テスト実行 |

参照スキル内の **`action` 条件はレガシー**。§0 の観測結果が常に優先する。payload に `action` があっても**無視**する。

## §0 観測と分岐（毎 run 先頭・固定順）

**payload は起動ヒントのみ。** `repository` + 任意の `issue_number` / `pr_number`（レガシー: `pr_unlinked`）。**ラベル名・payload フィールドで skip / merge 禁止を決めない。** 毎 run 先頭で `gh` 観測する。

0. **in-progress** — `agent-in-progress` または `agent-merge-in-progress` が付いていれば **即終了**（重複抑止。コメント不要）
1. **番号解決** — `pr_number` ありなら `gh pr view --json merged,closingIssuesReferences,state,mergeable,mergeStateStatus,labels`
   - **`merged: true`** → 再マージ禁止。リンク issue に `ux-campaign:breadcrumb` があれば post-merge のみ
   - **リンク issue あり** → PR フェーズ（[`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md)）へ
   - **リンク issue なし**（未リンク PR）→ PR フェーズ §0a（陳腐化観測）から。マージ経路には入らない
2. **open PR** — issue 起点でリンク issue の open PR を検索（`closingIssuesReferences`）
   - **あり** → PR フェーズ
   - **なし** → issue フェーズ（[`github-issue-worker`](../github-issue-worker/SKILL.md)）
3. **epic** — `[epic]` / `epic` ラベルなら §1b

### PR フェーズ: 陳腐化（obsolete）— Agent 判断

未リンク PR、または観測で陳腐化が疑われるとき [`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md) §0a を実施。

1. `gh pr diff` + 最近マージ済み PR と比較
2. obsolete → close
3. まだ有効 → exit 0（マージしない）
4. 判断不能 → コメント + exit 0

タイトル正規化や `#N` 参照の regex は **Agent 判断内のみ**（dispatch / reconcile スクリプトに書かない）。

### PR フェーズでやらないこと

- 新規 issue 実装
- 同一 issue に **2 つ目の PR** を開く

### issue フェーズでやらないこと

- squash merge（ready 化は **prep** 機械。Agent は `gh pr ready` しない）

### issue 実装経路（TDD GREEN 後・PR 前）

[`github-issue-worker`](../github-issue-worker/SKILL.md) §3 GREEN 確認後、**PR を開く前に必ず** [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) §4 を実施する。

1. `cleanup-workflow-tick.sh --parent-slug issue-<N>-<short-slug>` から開始（**tick 未実行で A1 に進まない**）
2. `WORKFLOW_COMPLETE` / gate exit 0 まで A〜D を回す
3. 完了後に [`github-issue-worker`](../github-issue-worker/SKILL.md) §5〜§6 で PR 作成（Draft。ready は prep）

PR フェーズでは sequential cleanup は行わない（上流 issue 実装 run で完了済みとみなす）。

### PR マージ成功後（同一 run）

[`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md) §4 で `gh pr merge` 成功直後、**この run を続行**する（別 webhook 不要。マージは常に本 Agent が行う）:

1. `gh pr view <N> --json closingIssuesReferences` でリンク issue を取得
2. 各 issue のラベルを `gh issue view --json labels` で確認
3. いずれかに `ux-campaign:breadcrumb` → [`ux-campaign-loop`](../ux-campaign-loop/SKILL.md) §1〜§2（scan → 残件起票 or 完了）。**実装 PR 禁止**
4. キャンペーンでなければ exit 0

キャンペーン issue かどうかは **issue ラベル**で判断する。workflow や dispatch lib で本文をパースしない。

## Webhook payload

```json
{
  "repository": "rick-chick/agrr",
  "issue_number": 323,
  "pr_number": 427
}
```

未リンク PR（`closingIssuesReferences` が空）:

```json
{
  "repository": "rick-chick/agrr",
  "pr_number": 430,
  "pr_unlinked": true
}
```

| フィールド | 必須 |
|-----------|------|
| `repository` | はい |
| `issue_number` | issue 起点時、または PR の `closingIssuesReferences` にリンク issue があるとき |
| `pr_number` | PR / CI 起点時 |
| `pr_unlinked` | `issue_number` が無い PR dispatch 時（`true`）。Agent は PR フェーズのみ |
| `action` | **送らない・無視** |

任意: `issue_title`, `issue_url`, `labels`, `retry_reason`。**`issue_body` / `body_hash` は機械層から送らない**（Agent は `gh issue view` で読む）。

## 依存

**機械層は依存を判定しない**（本文・コメント・依存ラベルのパース禁止）。`agent-ready` で webhook が届いたら Agent が `gh issue view` で本文を読み、hard 依存が OPEN なら **実装に着手せず** `agent-ready` を維持してコメントのみ残して終了する。依存が解消されたら通常どおり実装へ。

手順（Agent のみ）:

1. `gh issue view <N> --json body,labels` で本文と現行ラベルを読む
2. hard 依存を判断（regex・ヒューリスティックは SKILL 判断内のみ）
3. 依存未充足 → コメントで待機理由を残し exit 0（`agent-in-progress` は付けない）
4. 依存充足 → §3 着手宣言へ

## Automation（Cursor Dashboard）

| 項目 | 値 |
|------|-----|
| トリガー | **Webhook のみ** |
| 付けない | CI completed、Pull request opened（二重起動の元） |
| PR 作成 | ON |
| Memories | ON |

```
Read `.cursor/skills/delivery-agent/SKILL.md` exactly.
Payload: repository, issue_number, pr_number (optional). Legacy optional: pr_unlinked — do not trust; observe GitHub with gh and decide.
No action field — if present, ignore it. Never skip because of merge-prohibition labels.
Use referenced skills for implement and merge paths.
After TDD GREEN on issue implement path, run sequential-cleanup-review-workflow §4
(cleanup-workflow-tick.sh) before opening a PR. Do not skip tick or open PR before gate exit 0.
After gh pr merge succeeds, if a linked issue has ux-campaign:breadcrumb, continue the same run
with ux-campaign-loop §1–§2 (post-merge). Never disable the Delivery Agent automation.
```

**Secrets**: `CURSOR_DELIVERY_WEBHOOK_URL` / `CURSOR_DELIVERY_WEBHOOK_KEY`

## 切替（運用）

1. [Prefill](#prefill-urlフォーム事前入力) または Dashboard で **Delivery Automation** 作成（Webhook のみ）
   - **作成済み**: [AGRR Delivery Agent (Webhook)](https://cursor.com/automations/6a5cb2d9-8317-11f1-a7d1-d6b4613131ce)（`6a5cb2d9-8317-11f1-a7d1-d6b4613131ce`）
   - **プロンプトが古い場合**は [ワンクリック適用リンク](../cloud-automation-audit/references/cursor-automation-schedule.md#delivery-agentissue--merge-統合)を開いて **Save のみ**
2. `CURSOR_DELIVERY_WEBHOOK_URL` / `KEY` を repo secrets に登録
3. 旧 Automation を **OFF**（**workflow マージより先**）:
   - [AGRR Issue Worker (Webhook)](https://cursor.com/automations/6ad06db2-9fea-4a66-a56b-2cf7145f102d)
   - [AGRR GitHub Issue Worker](https://cursor.com/automations/8a78ac46-fe61-4eeb-827a-cca3a4acd742)
   - [AGRR PR Merge Worker](https://cursor.com/automations/dd9379bd-28c3-4e4b-8143-b5decc0ecd7e)
   - [AGRR UX Campaign Loop (Webhook)](https://cursor.com/automations/e3536984-7b74-11f1-ba66-0e7d0216e441)（post-merge は Delivery Agent に統合済み）
4. dispatch workflow マージ（本リポジトリ）
5. 切替後検証（下記）

リポジトリ側の準備確認: `node --test scripts/verify-delivery-agent-cutover-lib.test.mjs`

ロールバック: 旧 Automation ON + secrets を旧 URL に戻す + dispatch revert。

### 切替後検証（推奨）

| 確認 | 手順 |
|------|------|
| secrets 到達 | `issue-worker-dispatch` / `pr-merge-worker-dispatch` ログに `CURSOR_DELIVERY_WEBHOOK_* is not set` が**出ない**こと（未設定時は exit 0 で静かにスキップされる） |
| 旧 webhook 停止 | 旧 Automation OFF 後、旧 URL への POST が 0 件 |
| retry スモーク | `workflow_dispatch` on `issue-worker-retry-dispatch` / `pr-merge-worker-retry-dispatch` |
| E2E | `agent-ready` issue 1 件 → TDD → **sequential cleanup（tick → gate 0）** → Draft PR → prep ready → merge |
| deps | `## 依存` issue で Agent が依存未充足と判断 → コメントのみで終了。15 分 reconcile が再 dispatch |
