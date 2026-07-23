# Automation 判断基準（正本）

**いつ読むか**: Delivery Agent / dispatch / reconcile / Automation プロンプトの設計・修正・レビュー・実行の**すべて**で、迷ったら本ファイルを先に読む。

設計背景・目的の詳細は [PRINCIPLES.md](PRINCIPLES.md)。手順は [automation-authoring/SKILL.md](../SKILL.md)。本ファイルは **判断の可否を即決するための表**のみを載せる。

## 1. 二層の役割（不変）

| 層 | やること | やらないこと |
|----|----------|--------------|
| **機械**（Actions / `*-dispatch*.mjs`） | GitHub イベント検知 → webhook で Agent 起動。`agent-in-progress` / `agent-merge-in-progress` 等の**重複抑止のみ** | obsolete / close / merge 可否の決定、「触るな」ラベルの付与・解釈、Agent 向け経路名での分岐 |
| **Agent**（Automation + SKILL） | 毎 run 先頭で `gh` 観測 → close / 修正 / マージ / コメント / exit 0 | ラベル名・payload ヒントを**信用して skip** |

```
GitHub イベント → Actions（webhook 中継・重複抑止） → Delivery Agent（gh 観測で判断） → git push / gh issue / gh pr / close / merge
```

**reconcile** = 滞留への webhook **再送**まで。何をするかは Agent が観測して決める。

## 2. Agent 毎 run 先頭（固定順）

1. **重複抑止** — `agent-in-progress` または `agent-merge-in-progress` あり → 即 exit 0
2. **`gh` 観測** — `gh issue view` / `gh pr view` / `gh pr checks` で現状態を読む
3. **SKILL に従い分岐** — 実装 / §0a obsolete / コンフリクト解消 / CI 修正 / マージ / close / コメント待ち

payload の `issue_number` / `pr_number` は**起動ヒント**。観測結果と矛盾したら **観測が優先**。

## 3. 機械が読んでよい入力

| 可 | 不可 |
|----|------|
| `labels` の存在（`agent-in-progress` 等・重複抑止契約） | 本文・コメントのパース（`Closes #N`、依存 JSON、タイトル keyword） |
| `mergeable` / `mergeStateStatus` / `state`（イベント契約） | `closingIssuesReferences` で merge / §0a / obsolete を**機械が決める** |
| fork / `CHANGES_REQUESTED` 等の構造除外 | `agent-no-merge` / `do-not-merge` / `wip` の付与・解釈 |
| webhook payload: `repository`, `issue_number`, `pr_number`（`action` なし） | payload ヒントを Agent の skip 根拠にする設計 |

**例外（機械 prep のみ）**: `pr-agent-prep` は `closingIssuesReferences` **あり**の Draft PR を `gh pr ready` する。merge 可否・§0a の判断ではない。未リンクは prep をスキップする（ラベルは付けない）。

## 4. Agent が信用してはいけないもの

| 入力 | 正しい扱い |
|------|------------|
| optional payload フィールド（例: `pr_unlinked`） | `gh pr view` の `closingIssuesReferences` 等で確認 |
| `agent-no-merge` / `do-not-merge` / `wip` | **無視**。観測のみで着手可否を決める |
| payload `action` | 送らない。あっても無視 |

## 5. 設計・修正の Go / No-Go

**Go（採用）**

- 滞留 PR/issue へ reconcile が webhook を再送する
- 機械ゲートは重複抑止と構造フィールドのみ
- 判断が要るときは Agent を起動する（dispatch を減らすための機械判断は増やさない）
- Automation プロンプト更新は [prefill ワンクリック](../../../cloud-automation-audit/references/cursor-automation-schedule.md#delivery-agentissue--merge-統合)（開く → Save のみ）

**No-Go（拒否）**

- 「効率化」のため機械が merge / close / obsolete / 経路を決める
- 本文パース・例外ラベルで dispatch を止める
- Agent がラベルや payload ヒントで skip する SKILL / プロンプト
- 手動操作（`gh pr close`、Dashboard 手順の羅列）を本筋の救済にする
- `git diff` や会話だけで「たぶん」と設計・実装に入る
- `agent-no-merge` 等の判断印を機械が付ける設計
- Agent 向けに `conflict` / `ci_fix` / `pr_review` 等の経路名を payload や契約として載せる設計

## 6. 参照先

| 用途 | ファイル |
|------|----------|
| 判断基準（本ファイル） | `JUDGMENT-CRITERIA.md` |
| 目的・全部拾う・ラベル契約 | [PRINCIPLES.md](PRINCIPLES.md) |
| dispatch 追加・変更手順 | [automation-authoring/SKILL.md](../SKILL.md) |
| Agent 実行（issue→merge） | [delivery-agent/SKILL.md](../../delivery-agent/SKILL.md) |
| PR マージ・§0a | [github-pr-merge-worker/SKILL.md](../../github-pr-merge-worker/SKILL.md) |
| cron / prefill / secrets | [cursor-automation-schedule.md](../../cloud-automation-audit/references/cursor-automation-schedule.md) |
| パイプライン俯瞰 | [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) |
