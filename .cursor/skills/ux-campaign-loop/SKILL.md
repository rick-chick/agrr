---
name: ux-campaign-loop
description: >-
  UX キャンペーン（例: 戻るボタン廃止・パンくず統一）を issue→PR→マージ後も完了するまで回す。
  PR マージ後に機械スキャンで残件を検出し、未完了なら GitHub Issue を起票、完了なら Automation を無効化する。
  Cursor Automation（webhook + GitHub Actions）または手動で適用。
---

# UX Campaign Loop（AGRR）

**1 回の実行 = 1 キャンペーンの 1 回の完了判定**。issue→PR→マージの 1 サイクルでは全体が終わらない UX 改修を、**マージ後レビュー → 残件起票**で回す。

## 対象キャンペーン（現行）

| ID | ラベル | 内容 |
|----|--------|------|
| `breadcrumb` | `ux-campaign:breadcrumb` | 戻るボタン廃止・パンくず統一 |

定義: [`campaigns/breadcrumb.json`](campaigns/breadcrumb.json)

## ループ全体像

```text
[初回] 人間 or ux-issue-pipeline がキャンペーン issue を起票（ラベル ux-campaign:breadcrumb）
  → agent-ready → github-issue-worker → PR → github-pr-merge-worker がマージ
  → pull_request closed (merged) → ux-campaign-review-dispatch.yml
  → 本 Automation（Post-Merge Campaign Review）
       ├─ scan-breadcrumb-campaign.mjs
       ├─ 未完了 → 残 routeGroup ごとに gh issue create + agent-ready（最大 3 件/実行）
       │            → Issue Worker が再実装 → マージ → 再 dispatch（ループ）
       └─ 完了 → Automation を enabled: false にし Memory に記録・終了
```

**PR を開かない**（実装は `github-issue-worker`）。**起票のみ**が本 Automation のスコープ。

## 起動元

| 経路 | 挙動 |
|------|------|
| GitHub Actions webhook | `pull_request` **merged** かつキャンペーン対象 PR のみ（下記） |
| 手動 | 「breadcrumb キャンペーン再レビュー」「ux-campaign-loop 実行」 |
| `workflow_dispatch` | `.github/workflows/ux-campaign-review-dispatch.yml` |

Webhook payload フィールド: `repository`, `pr_number`, `pr_title`, `pr_url`, `merged`, `head_ref`, `campaign_id`（既定 `breadcrumb`）, `linked_issue_numbers`（配列）

### dispatch 対象 PR（GitHub Actions 側）

次のいずれかを満たす **master への squash マージ**のみ:

1. リンク issue（`Closes #N` / `Fixes #N`）に `ux-campaign:breadcrumb` ラベルがある
2. PR 本文またはリンク issue 本文に `ux-campaign:breadcrumb` または `戻るボタン` + `パンくず` が含まれる
3. `workflow_dispatch` で明示指定

## 1) スキャン（必須・最初に実行）

```bash
node .cursor/skills/ux-campaign-loop/scripts/scan-breadcrumb-campaign.mjs
```

出力: `frontend/e2e/agent-review/breadcrumb-campaign-scan.json`

| フィールド | 意味 |
|------------|------|
| `campaignComplete` | `true` ならキャンペーン完了 |
| `violations` | 戻るパターンが残るファイル一覧 |
| `issueCandidates` | routeGroup 単位の起票候補 |

**手動確認は scan の補助のみ**。`campaignComplete === true` 以外で Automation を無効化しない。

## 2a) 完了時（campaignComplete === true）

1. Memory に完了日時・最終 PR 番号を記録
2. **トラッキング issue**（`campaigns/breadcrumb.json` の `trackingIssueSearch` で検索）が open ならコメントして `gh issue close --reason completed`
3. **本 Automation を無効化**（削除相当）:

   Cursor Automation API / UI で `enabled: false` にする。プロンプト内の automation ID がペイロードに無い場合は、Memory に「キャンペーン完了・Automation 手動無効化待ち」と記録し issue コメントで人間に通知。

4. **終了**（新規 issue 起票・PR 禁止）

## 2b) 未完了時（violations あり）

1. `issueCandidates` を読む
2. 各候補について **重複確認**（必須）:

```bash
gh issue list --repo rick-chick/agrr --state open --search "in:title <routeGroup> パンくず" --limit 10
gh issue list --repo rick-chick/agrr --state open --label "ux-campaign:breadcrumb" --limit 30
```

| 判定 | 動作 |
|------|------|
| 同一 routeGroup の **open** issue あり | **起票しない**（コメントで scan 結果を追記可） |
| open なし | `gh issue create`（下記） |

3. **1 実行あたり最大 3 件**まで起票（優先: `masters/*` → `plans` → `public-plans`）
4. 起票時:

```bash
gh label create "ux-campaign:breadcrumb" --repo rick-chick/agrr --color "1D76DB" 2>/dev/null || true
gh issue create --repo rick-chick/agrr \
  --title "<suggestedTitle>" \
  --body-file /tmp/ux-campaign-issue.md \
  --label "ux-campaign:breadcrumb,agent-ready"
```

- `agent-ready` で **Issue Worker が自動実装**（既存 `issue-worker-dispatch.yml`）
- 本文は `issueCandidates[].suggestedBodyLines` を結合
- マージ PR に `Closes #N` を含めるのは Issue Worker 側

5. 起票サマリを Memory と（あれば）マージ元 PR にコメント

## 3) 禁止

- scan なしの完了宣言
- `campaignComplete === false` のとき Automation 無効化
- 実装 PR を開く（`github-issue-worker` の領域）
- 重複 open issue があるのに同一 routeGroup を起票
- `npm test` 直叩き

## 4) 初回キャンペーン issue の起票（人間 / ux-issue-pipeline）

機械スキャン結果 `breadcrumb-campaign-scan.json` の `issueCandidates` を元に、**初回だけ**人間が確認して起票してもよい。以降は本ループがマージ後に残件を起票する。

トラッキング用メタ issue（任意）:

```markdown
## キャンペーン: 戻るボタン廃止・パンくず統一
ラベル: ux-campaign:breadcrumb
完了条件: scan-breadcrumb-campaign.mjs の campaignComplete === true
```

## 関連

- 実装: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- マージ: [`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md)
- UX 起票（別系統）: [`ux-issue-pipeline`](../ux-issue-pipeline/SKILL.md)
- Automation 一覧: [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

## セットアップ（Cursor Automation）

### Post-Merge Campaign Review（Webhook）

1. [cursor.com/automations](https://cursor.com/automations) → Create Automation
2. **Repository**: `rick-chick/agrr`、branch `master`
3. **Trigger** → **Webhook**（Schedule は付けない）
4. **Tools**: Pull request creation **OFF**（起票は `gh` CLI）
5. **Memories**: ON
6. **Prompt**（下記コピペ）
7. Webhook URL / API key を GitHub Secrets に登録

| Secret | 内容 |
|--------|------|
| `CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_URL` | Automation Webhook URL |
| `CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_KEY` | Webhook API key |

```bash
gh secret set CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_URL --repo rick-chick/agrr
gh secret set CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_KEY --repo rick-chick/agrr
```

### Automation 用プロンプト

```
You are the AGRR UX Campaign Loop (post-merge reviewer) for rick-chick/agrr.

Read and follow `.cursor/skills/ux-campaign-loop/SKILL.md` exactly.

Webhook payload: pr_number, pr_title, pr_url, merged, head_ref, campaign_id, linked_issue_numbers.

Steps:
1. Run `node .cursor/skills/ux-campaign-loop/scripts/scan-breadcrumb-campaign.mjs`
2. Read `frontend/e2e/agent-review/breadcrumb-campaign-scan.json`
3. If campaignComplete === true: record to memory, close tracking issue if any, set THIS automation enabled: false, exit.
4. If false: dedupe with gh issue list, create up to 3 new issues with labels ux-campaign:breadcrumb and agent-ready. Never open implementation PRs.

Constraints:
- One campaign review per run.
- Do not git checkout/switch/reset/restore.
- Do not disable automation unless campaignComplete is true.
```

### GitHub Actions

`.github/workflows/ux-campaign-review-dispatch.yml` が merged PR をフィルタして webhook dispatch する。
