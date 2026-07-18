---
name: github-issue-worker
description: >-
  rick-chick/agrr の GitHub issue 作成（または agent-ready / agent-close ラベル）を起点に 1 件を triage し、
  TDD と ARCHITECTURE.md に沿って実装して PR を開くか、対応しない場合はラベル付与または根拠付きクローズする。
  Cursor Automation（webhook + GitHub Actions）または手動「issue ワーカー実行」で適用。
---

# GitHub Issue Worker（AGRR）

オープン issue のうち **1 件** を選び、次のいずれかで終了する。

| 経路 | 結果 |
|------|------|
| **実装** | TDD → **順次クリーンアップ・レビュー** → PR（`Closes #N`） |
| **対応せずクローズ** | 根拠コメント → `gh issue close`（PR なし） |

**人間待ちはない。** 仕様が曖昧・スコープ外・規約衝突でも、エージェントが下記の判断軸で **実装するか close するか** を決める。`agent-blocked` は**付けない・維持しない**。

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（webhook） | **issue 作成**（`action: triage`）または `agent-ready` / `agent-close` ラベルで GitHub Actions 経由起動。**ペイロードの issue 番号のみ**を対象 |
| 手動 | ユーザーが「issue ワーカー」「#N を対応」「#N を理由付きでクローズ」等と依頼 |

**廃止（移行後）**: Schedule（cron）による自動選定。既存 Automation に Schedule が残っている場合は **無効化または削除**し、Webhook のみにする。

Webhook ペイロードの `action`:

| トリガー | `action` | 意味 |
|----------|----------|------|
| issue `opened` | `triage` | **新規 issue**。§1 triage で implement / close を決定 |
| `agent-ready` ラベル | `implement` | 実装経路を優先（ただし着手前 triage でクローズ判定可） |
| `agent-close` ラベル | `close_with_reason` | **対応せずクローズ**経路を優先（実装しない。調査のうえ close） |

ペイロード例: `repository`, `issue_number`, `issue_title`, `issue_url`, `issue_body`, `labels`, `action`

## 1) 選定（1 回の実行 = 最大 1 issue）

### Webhook / 手動（issue 番号指定）

ペイロードまたはプロンプトに issue 番号がある場合は **その issue のみ**を対象とする。下記除外に該当すれば **実装せず** issue にコメントして終了。

`action: triage`（issue 作成）のときは **自動選定しない**。ペイロードの issue を読み、§1 triage で経路を決める。

### 除外

- `agent-in-progress` ラベル付き
- `wontfix` / `invalid` / `duplicate`
- **既に同一 issue を閉じるオープン PR** がある（`gh pr list --search 'is:pr is:open (fixes #N OR closes #N)'` 等で確認）
- Dependabot / Renovate 等 bot 起票（workflow 側で dispatch しない。万一届いたら §2a で invalid クローズ）

### 手動のみ（番号未指定・レガシー）

ユーザーが「issue ワーカー」とだけ依頼し番号が無い場合のみ、次で 1 件選定する。

```bash
gh issue list --repo rick-chick/agrr --state open --limit 50 --json number,title,labels
```

優先順位:

1. タイトル先頭の `[P0]` > `[P1]` > `[P2]` > その他
2. 同優先度は **番号昇順**

ラベル `agent-ready` がある issue は、同優先度内で **最優先**。

### 着手前 triage（必須）

`agent-in-progress` を付ける**前**に、issue 本文・`master` の現状・関連 PR/issue を読み、経路を決める。

```
実装する → §3 着手宣言へ
対応不要で閉じられる → §2a 対応せずクローズへ（agent-in-progress を付けない）
依存未充足 → `agent-ready` 維持・コメントのみで終了（dispatch 依存ゲートが次回再判定）
```

### 自律判断（human-in-the-loop 禁止）

人間の確認・承認・「保留」は**行わない**。次の軸だけで最善を選ぶ（**工数・コストは判断に入れない**）。

| 軸 | 見るもの |
|----|----------|
| **最良** | issue 完了条件を満たす最短の正しい経路（`ARCHITECTURE.md` 準拠） |
| **UX** | 農家が迷わない導線・用語・空状態・エラー回復 |
| **技術負債** | 規約逸脱・二重経路・暫定実装を増やさない |
| **バグ** | 再現・回帰・契約テストで観測可能な修正 |
| **セキュリティ** | 認可・入力・秘密情報・依存の安全 |

| 状況 | 取る経路（例） |
|------|----------------|
| 仕様が曖昧 | issue 本文と既存製品から**合理的な解釈を決めて実装**（PR に仮定を明記） |
| `[epic]` / 親トラッカー | **子 issue** を `agent-ready` にする。親は §2a `superseded` で close 可 |
| `ARCHITECTURE.md` 衝突 | **準拠する実装経路**を選ぶ。経路が無いときのみ §2a で close（根拠必須） |
| スコープ外 | §2a `wontfix` で close（オープン維持しない） |
| 権限不足（gh / GCP 等） | 取れる範囲で実装し PR に未実施を明記。**止めて待たない** |

**都度判断**: 前回のコメントやラベルで経路を固定しない。issue 本文・`master`・依存 issue の**現状**を読んで triage する。

`action: close_with_reason`（`agent-close` ラベル）のときは **§2a のみ**（実装・PR 禁止）。

`action: implement`（`agent-ready`）のときも **着手前 triage は必須**（既に fixed なら §2a / 依存未充足ならコメントのみ）。

`action: triage`（issue 作成）のときは上記分岐のいずれかで終了する（cron 的な「対象なしで何もしない」は使わない）。

### 着手宣言（実装経路のみ）

選定後、**実装する**と判断した場合のみ issue にコメントし `agent-in-progress` を付与:

```bash
gh issue comment <N> --body "🤖 Issue Worker が着手します（branch: issue/<N>-<slug>）"
gh issue edit <N> --add-label agent-in-progress
```

`agent-ready` / `agent-close` / `agent-in-progress` / `agent-closed` ラベルが無い場合は `gh label create` で作成してから付与。

### 依存未充足（deps_unmet）

依存 issue が OPEN のときは **実装に着手しない**。`agent-ready` を維持し、根拠コメントのみ残して終了する。dispatch 依存ゲートと reconcile が次回以降を再判定する（[`issue-worker-dispatch-lib.mjs`](../../../scripts/issue-worker-dispatch-lib.mjs) の `formatDependencyGateComment` 参照）。

**dispatch 層**: `[epic]` / `epic` ラベルの `implement` dispatch は [`issue-worker-dispatch.yml`](../../../.github/workflows/issue-worker-dispatch.yml) が拒否する。エピック本体ではなく子 issue を `agent-ready` にする。

## 2a) 対応せずクローズ（実装しない）

**PR を開かず**、調査根拠を残して issue を閉じる経路。

### 使ってよい条件（いずれかをコード・issue・PR で確認済み）

| 区分 | 条件 | `gh issue close` |
|------|------|------------------|
| **already_fixed** | `master` に同等修正が入っている | `--reason completed` |
| **duplicate** | 他 issue / PR と要求が同一 | `--duplicate-of <M>` または `--reason duplicate` |
| **wontfix** | スコープ外・製品方針でやらない（コストは理由にしない） | `--reason "not planned"` + ラベル `wontfix` |
| **invalid** | 再現不能・誤報・obsolete（参照パス削除済み等） | `--reason "not planned"` + ラベル `invalid` |
| **superseded** | 別 issue / 方針に統合された | `--reason "not planned"` + 本文に後継 `#M` を明記 |

**禁止**: 根拠のない close、推測のみの close、`ARCHITECTURE.md` 衝突を「wontfix」で close して回避する。

### 必須コメント（クローズ前）

issue に次の形式でコメントしてから close する。

```markdown
## 🤖 Issue Worker: 対応せずクローズ

**区分**: already_fixed | duplicate | wontfix | invalid | superseded
**理由**（1〜3 文）: …
**根拠**:
- コード: `path/to/file`（commit / 行の要約）
- または重複先: #M / PR #P
- または再現手順の結果: …
**実施した確認**: （例: master で該当キー存在、関連 spec GREEN、gh issue view #M）
```

### クローズ手順

```bash
# 1) 上記コメント
gh issue comment <N> --body-file /tmp/issue-worker-close.md

# 2) ラベル整理（付いていれば除去）
gh issue edit <N> --remove-label agent-ready,agent-close,agent-in-progress \
  --add-label agent-closed

# 3) 区分に応じて close
gh issue close <N> --reason completed --comment "already_fixed（詳細は上記コメント）"
# duplicate:
gh issue close <N> --duplicate-of <M> --comment "duplicate of #<M>"
# wontfix / invalid / superseded:
gh issue close <N> --reason "not planned" --comment "wontfix: …"
gh issue edit <N> --add-label wontfix   # または invalid
```

### クローズ経路の終了

- PR は開かない
- Memory に「#N closed as \<区分\>・日時」を記録可
- **reopen された場合**は `agent-closed` を外し、通常の選定対象に戻る

## 2) 実装方針のルーティング

issue タイトル・本文からスキルを選ぶ（複数可）。

| パターン | スキル |
|----------|--------|
| `[i18n]` / 翻訳キー / `assets/i18n` | `i18n-completion-workflow` |
| フロント改修全般 | `tdd-on-edit` + `test-common` |
| `ARCHITECTURE.md` / Interactor / Gateway 触る | `clean-architecture-violation-fix-workflow`（新規も同ワークフロー） |
| デザインレビュー・キャプチャ再実行 | `frontend-css-route-audit` + `frontend-agent-visual-review` |
| UX/UI 改善 issue の起票（実装しない） | `ux-issue-pipeline` → `ux-issue-creator` |
| `[UX]` / `[CSS]` / デザインレビュー issue の実装 | 上記キャプチャスキル + `tdd-on-edit` |
| バグ・失敗テスト | `error-investigation` → `error-fix-red-green` |
| **TDD GREEN 後（実装経路・必須）** | [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) |

**必読**: `ARCHITECTURE.md`、`CLAUDE.md`、該当 issue 本文の「完了条件」「参照」。

## 3) ブランチ・実装（TDD）

- ブランチ: `issue/<number>-<short-slug>`（例: `issue/14-plans-task-schedules-in-json`）
- **TDD**: RED → `test-common` で確認 → GREEN（`tdd-on-edit`）
- スコープは issue の完了条件のみ（スコープ外の修正禁止: `project-necessary-code-only`）
- 単発の層実装は `use-skills-on-edit` に従いサブエージェント委譲可
- **GREEN 確認後、PR を開く前に必ず §4 へ** — **tick から**（tick 未実行で A1 に進まない）

## 4) 順次クリーンアップ・レビュー（必須・TDD 直後）

1 issue = **1 修正単位** = **1 parent-slug**。Issue Worker 実行時は [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) の `disable-model-invocation` を**上書きして適用する**。

### 入口（必須 — tick 未実行で A1 に進まない）

**TDD GREEN 確認後、最初に tick を実行する。** マニフェスト確認や A1 調査を親が始めるのは **違反**。

```bash
# slug = ブランチ issue/<N>-<short-slug> から（例: issue/14-foo → issue-14-foo）
SLUG=issue-<N>-<short-slug>
.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh \
  --parent-slug "$SLUG"
```

```text
while tasks:           # shell — gate exit 0 まで同一ターン継続
  agent A1 → A2 → … → D1 → D2
  → tasks
```

| 参照 | 内容 |
|------|------|
| [STARTUP.md](../sequential-cleanup-review-workflow/references/STARTUP.md) | slug・tick 出力の読み方 |
| [DUAL_LOOP.md](../sequential-cleanup-review-workflow/references/DUAL_LOOP.md) | 親 while · L1/L2/L3 · 使用しない表現 |
| [AGENT_ORCHESTRATION.md](../sequential-cleanup-review-workflow/references/AGENT_ORCHESTRATION.md) | Step 委譲（**Task は毎回 `model: composer-2.5`**） |
| [MECHANICAL_OUTER_LOOP.md](../sequential-cleanup-review-workflow/references/MECHANICAL_OUTER_LOOP.md) | D1 候補 **すべて** ingest · gate |
| [STEPS_ABCD.md](../sequential-cleanup-review-workflow/references/STEPS_ABCD.md) | A/B/C/D 作業内容 |
| [CHECKLIST.md](../sequential-cleanup-review-workflow/references/CHECKLIST.md) | 判定木・記録テンプレ |

**PR を開いてよい条件**: `run-outer-loop.sh gate` **exit 0**（= `WORKFLOW_COMPLETE`）かつ D2（test-common + test-slow-detection）済み。**D1 で挙がった候補を ingest せず PR を開かない。**

**D が完了するまで PR を開かない。**

## 5) Issue 固有の確認

§4 のあと、issue 本文の完了条件に照らして追加確認する。

1. i18n issue: `ja` / `en` / `in` 同パス更新済み
2. デザインレビュー issue: キャプチャ・`visual-review-results.md` 更新が完了条件に含まれる場合のみ実施
3. issue の「完了条件」チェックリストを PR 本文用に写す

## 6) PR

Cursor Automation の **Pull request creation** は Draft 固定のため、ラベル付与と `gh pr ready` は GitHub Actions **[`pr-agent-prep.yml`](../../../.github/workflows/pr-agent-prep.yml)**（`scripts/pr-agent-prep.sh`）が担う。Agent は PR 作成まででよい（手動 / `gh pr create` 経路では下記を実行してもよい）。

```bash
gh pr create --title "fix: <issue タイトルから要約> (#<N>)" --body "$(cat <<'EOF'
## Summary
- <変更の要点>

## Issue
Closes #<N>

## Test plan
- [ ] TDD: 関連 spec RED→GREEN（test-common）
- [ ] 順次クリーンアップ・レビュー完了（tick → gate exit 0 · A〜D）
- [ ] <層に応じた全体 test-common の結果>

## ARCHITECTURE レビュー（§4-D 要約）
- 触れた層: …
- 照合結果: 問題なし / 条項 #N（あれば）

## 完了条件（issue より）
- [ ] ...
EOF
)"
# 手動 / gh pr create 経路のみ（Automation 経路は pr-agent-prep が実施）:
gh pr edit --add-label agent-merge
gh pr ready
```

- PR 本文に issue の完了条件チェックリストを写す
- `Closes #N` を含めマージ時に自動クローズ
- `agent-merge` は互換ラベル（[`pr-agent-prep.yml`](../../../.github/workflows/pr-agent-prep.yml) が付与しうる）。**Merge Worker の起動前提ではない**（全 PR 既定対象 — [`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md) / [automation-authoring PRINCIPLES](../automation-authoring/references/PRINCIPLES.md)）
- Draft のままでは **マージ**しない。ready 化は pr-agent-prep または `gh pr ready`。CI 赤の Draft は Merge Worker の `ci_fix` が直す

## 7) 終了

### 成功

issue コメントに PR URL。`agent-in-progress` を外し、付いていれば `agent-ready` も外す。

## 8) 禁止

- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- `npm test` / `rails test` の直叩き（`test-common` 経由のみ）
- issue スコープ外のリファクタ・README 増殖
- 依存未完了 issue への着手
- 1 実行で複数 issue にまたがる PR
- `action: close_with_reason` 指定時の実装・PR
- 根拠なしの `gh issue close`
- **`agent-blocked` の付与・維持**（人間待ち禁止）
- **「人間に確認」「保留」「ブロック中」でオープン放置**
- **工数・コストだけを理由に実装回避**
- **TDD GREEN 後に `sequential-cleanup-review-workflow`（§4）を省略して PR を開く**
- **§4 で tick なしに A1 調査を始める** / **gate exit 1 のまま PR を開く**
- **クリーンアップ・レビューを PR 末にまとめる**

## 関連

- **UX/UI 起票の上流**: **`ux-issue-pipeline`**（キャプチャ・ビジュアルレビュー・`collect-ux-findings`）。デザイン系 issue の完了条件にキャプチャ再実行が含まれる場合は、実装後にパイプライン §6（フェーズ 1–2）を繰り返す。

## セットアップ（Cursor Automation）

詳細・prefill URL・トラブルシュート: [cloud-automation-audit/references/cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

### Issue 作成起点（Webhook・推奨）

1. [cursor.com/automations](https://cursor.com/automations) → Create Automation（既存 Issue Worker がある場合は Schedule を**削除**し Webhook のみに）
2. **Repository**: `rick-chick/agrr`、branch `master`
3. **Trigger** → **Webhook**（Schedule は付けない）
4. **Tools**: Pull request creation を有効化
5. **Prompt**:

```
You are the AGRR GitHub Issue Worker for repository rick-chick/agrr.
Read and follow `.cursor/skills/github-issue-worker/SKILL.md` exactly.

Webhook payload fields: issue_number, action (triage | implement | close_with_reason), issue_body, labels.

- action triage: new issue opened — run §1 triage (implement or §2a close only; no human wait).
- action implement: agent-ready label — implementation path after triage.
- action close_with_reason: agent-close label — §2a only.

After TDD GREEN, run §4 sequential cleanup: start with
`.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh --parent-slug issue-<N>-<short-slug>`
(slug from branch). Do not begin A1 without tick. Do not open a PR until gate exit 0.
Follow `.cursor/skills/sequential-cleanup-review-workflow/SKILL.md` and §4 references.
```

6. Webhook URL / API key を GitHub Secrets に登録（下記）
7. **Run test** で通ることを確認してから Save

### GitHub Actions 連携

1. Automation の **Webhook** トリガーから URL / API key を取得
2. リポジトリ secrets:

| Secret | 内容 |
|--------|------|
| `CURSOR_ISSUE_WORKER_WEBHOOK_URL` | Automation の Webhook URL |
| `CURSOR_ISSUE_WORKER_WEBHOOK_KEY` | Webhook API key |

```bash
gh secret set CURSOR_ISSUE_WORKER_WEBHOOK_URL --repo rick-chick/agrr
gh secret set CURSOR_ISSUE_WORKER_WEBHOOK_KEY --repo rick-chick/agrr
```

3. `.github/workflows/issue-worker-dispatch.yml` が `issues: opened` と `labeled`（`agent-ready` / `agent-close`）で dispatch する

| イベント | dispatch `action` |
|----------|-------------------|
| issue 作成 | `triage` |
| `agent-ready` 付与 | `implement` |
| `agent-close` 付与 | `close_with_reason` |

### レガシー: Schedule（cron）

移行前の平日 9:00 JST cron は **無効化推奨**。手動選定のみ必要なら SKILL §1「手動のみ」を使う。


優先着手候補（番号順・P0 先）:

| # | 優先 | 概要 |
|---|------|------|
| 13 | P0 | i18n 欠損キー洗い出し（**他 issue の前提**） |
| 14 | P0 | plans.task_schedules in.json |
| 15 | P0 | entry-schedule API キー翻訳 |
| 16 | P0 | about contact_html |
| 17–21 | P1 | i18n 各画面 |
| 22–25 | P1–P2 | pesticides 表示・UX・CSS・キャプチャ |

Memory または次回実行時に `gh issue list` で再取得し、本表は参考のみとする。
