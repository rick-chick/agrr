---
name: ux-campaign-loop
description: >-
  UX キャンペーン（例: 戻るボタン廃止・パンくず統一）の post-merge レビュー。
  Delivery Agent が PR マージ成功後の同一 run で呼び出す参照スキル（scan・残件起票・完了記録）。
---

# UX Campaign Loop（AGRR）

**Delivery Agent の PR マージ成功後フック**。独立 Automation / 専用 dispatch workflow は使わない。

**1 回の呼び出し = 1 キャンペーンの 1 回の完了判定**。issue→PR→マージの 1 サイクルでは全体が終わらない UX 改修を、**マージ後レビュー → 残件起票**で回す。

## 対象キャンペーン（現行）

| ID | ラベル | 内容 |
|----|--------|------|
| `breadcrumb` | `ux-campaign:breadcrumb` | 戻るボタン廃止・パンくず統一 |

定義: [`campaigns/breadcrumb.json`](campaigns/breadcrumb.json)

## ループ全体像

```text
[初回] ux-issue-pipeline 等がキャンペーン issue を起票（ラベル ux-campaign:breadcrumb）
  → agent-ready → Delivery Agent（実装）→ PR → Delivery Agent（マージ）
  → 同一 run で本 SKILL（post-merge）
       ├─ scan-breadcrumb-campaign.mjs
       ├─ 未完了 → 残 routeGroup ごとに gh issue create + agent-ready（最大 3 件/実行）
       │            → Delivery Agent が再実装 → マージ → 再 post-merge（ループ）
       └─ 完了 → Memory に記録・トラッキング issue close・終了
```

**PR を開かない**（実装は Delivery Agent / `github-issue-worker`）。**起票のみ**が本 SKILL のスコープ。

## 起動元

| 経路 | 挙動 |
|------|------|
| **Delivery Agent** | [`delivery-agent`](../delivery-agent/SKILL.md) が `gh pr merge` 成功直後、リンク issue に `ux-campaign:breadcrumb` があれば同一 run で本 SKILL §1〜§2 を実行 |
| 手動 | Delivery Agent run 内で本 SKILL を読んで再実行（別 Automation 不要） |

### キャンペーン issue の見分け方（エージェント判定）

- リンク issue（`gh pr view --json closingIssuesReferences`）のラベルに **`ux-campaign:breadcrumb`** があるか
- 必要なら `gh issue view` で本文も読む（**workflow / dispatch lib で本文パースしない**）
- キャンペーンでなければ **何もせず exit 0**

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

**手動確認は scan の補助のみ**。`campaignComplete === true` 以外で「完了」と宣言しない。

## 2a) 完了時（campaignComplete === true）

1. Memory に完了日時・最終 PR 番号を記録
2. **トラッキング issue**（`campaigns/breadcrumb.json` の `trackingIssueSearch` で検索）が open ならコメントして `gh issue close --reason completed`
3. **終了**（新規 issue 起票・PR 禁止）

**Delivery Agent Automation は無効化しない**（本 SKILL はその一部）。

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

- `agent-ready` で **Delivery Agent** が自動実装
- 本文は `issueCandidates[].suggestedBodyLines` を結合

5. 起票サマリを Memory と（あれば）マージ元 PR にコメント

## 3) 禁止

- scan なしの完了宣言
- Delivery Agent Automation の無効化
- 実装 PR を開く（`github-issue-worker` / Delivery Agent 実装経路の領域）
- 重複 open issue があるのに同一 routeGroup を起票
- `npm test` 直叩き

## 4) 初回キャンペーン issue の起票（ux-issue-pipeline 等）

機械スキャン結果 `breadcrumb-campaign-scan.json` の `issueCandidates` を元に起票してもよい。以降は Delivery Agent マージ後の post-merge が残件を起票する。

トラッキング用メタ issue（任意）:

```markdown
## キャンペーン: 戻るボタン廃止・パンくず統一
ラベル: ux-campaign:breadcrumb
完了条件: scan-breadcrumb-campaign.mjs の campaignComplete === true
```

## 関連

- 起動元: [`delivery-agent`](../delivery-agent/SKILL.md)
- 実装: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- マージ: [`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md)
- UX 起票（別系統）: [`ux-issue-pipeline`](../ux-issue-pipeline/SKILL.md)
- Automation 一覧: [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

## レガシー（廃止）

- 独立 Cursor Automation（Webhook）`e3536984-7b74-11f1-ba66-0e7d0216e441` — **OFF**
- `.github/workflows/ux-campaign-review-dispatch.yml` — **削除済み**
- Secrets `CURSOR_UX_CAMPAIGN_REVIEW_WEBHOOK_*` — 不要
