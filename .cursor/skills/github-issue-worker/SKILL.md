---
name: github-issue-worker
description: >-
  rick-chick/agrr のオープン GitHub issue を優先度・依存関係に従って 1 件選び、
  TDD と ARCHITECTURE.md に沿って実装し、順次クリーンアップ・レビュー後に PR を開く。
  実装不要と判断した場合は根拠付きでクローズする。Cursor Automation（cron / webhook）または手動「issue ワーカー実行」で適用。
---

# GitHub Issue Worker（AGRR）

オープン issue のうち **1 件** を選び、次のいずれかで終了する。

| 経路 | 結果 |
|------|------|
| **実装** | TDD → **順次クリーンアップ・レビュー** → PR（`Closes #N`） |
| **対応せずクローズ** | 根拠コメント → `gh issue close`（PR なし） |
| **ブロック** | 理由コメント → **オープンのまま** `agent-blocked` |
| **対象なし** | 何もしない |

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（cron） | 平日 9:00 JST（UTC 0:00）。対象 issue を自動選定 |
| Cursor Automation（webhook） | `agent-ready` または `agent-close` ラベルで GitHub Actions 経由起動。**その issue 番号を優先** |
| 手動 | ユーザーが「issue ワーカー」「#N を対応」「#N を理由付きでクローズ」等と依頼 |

Webhook ペイロードの `action`:

| ラベル | `action` | 意味 |
|--------|----------|------|
| `agent-ready` | `implement` | 実装経路を優先（ただし着手前 triage でクローズ判定可） |
| `agent-close` | `close_with_reason` | **対応せずクローズ**経路を優先（実装しない。調査のうえ close） |

## 1) 選定（1 回の実行 = 最大 1 issue）

### 除外

- `agent-in-progress` ラベル付き
- `wontfix` / `invalid` / `duplicate`
- 本文に「ブロック中」「保留」と明記されているもの
- **既に同一 issue を閉じるオープン PR** がある（`gh pr list --search "fixes #N"` 等で確認）

### Webhook 起動時

ペイロードまたはプロンプトに issue 番号がある場合は **その issue のみ** を対象とする。上記除外に該当すれば **実装せず** issue にコメントして終了。

### Cron / 手動（自動選定）

```bash
gh issue list --repo rick-chick/agrr --state open --limit 50 --json number,title,labels
```

優先順位:

1. タイトル先頭の `[P0]` > `[P1]` > `[P2]` > その他
2. 同優先度は **番号昇順**（#13 が i18n Phase 0 の前提）
3. 本文の「依存」節に未完了 issue 番号がある場合は **依存が閉じるまでスキップ**

ラベル `agent-ready` / `agent-close` がある issue は、同優先度内で **最優先**（`agent-close` はクローズ専用経路）。

### 着手前 triage（必須）

`agent-in-progress` を付ける**前**に、issue 本文・`master` の現状・関連 PR/issue を読み、経路を決める。

```
実装する → §3 着手宣言へ
対応不要で閉じられる → §2a 対応せずクローズへ（agent-in-progress を付けない）
人間の判断が要る → §7 ブロックへ
```

`action: close_with_reason`（`agent-close` ラベル）のときは **§2a のみ**（実装・PR 禁止）。

### 着手宣言（実装経路のみ）

選定後、**実装する**と判断した場合のみ issue にコメントし `agent-in-progress` を付与:

```bash
gh issue comment <N> --body "🤖 Issue Worker が着手します（branch: issue/<N>-<slug>）"
gh issue edit <N> --add-label agent-in-progress
```

`agent-ready` / `agent-close` / `agent-in-progress` / `agent-blocked` / `agent-closed` ラベルが無い場合は `gh label create` で作成してから付与。

## 2a) 対応せずクローズ（実装しない）

**PR を開かず**、調査根拠を残して issue を閉じる経路。`agent-blocked`（オープン保留）とは別。

### 使ってよい条件（いずれかをコード・issue・PR で確認済み）

| 区分 | 条件 | `gh issue close` |
|------|------|------------------|
| **already_fixed** | `master` に同等修正が入っている | `--reason completed` |
| **duplicate** | 他 issue / PR と要求が同一 | `--duplicate-of <M>` または `--reason duplicate` |
| **wontfix** | スコープ外・製品方針・コスト対効果でやらない | `--reason "not planned"` + ラベル `wontfix` |
| **invalid** | 再現不能・誤報・obsolete（参照パス削除済み等） | `--reason "not planned"` + ラベル `invalid` |
| **superseded** | 別 issue / 方針に統合された | `--reason "not planned"` + 本文に後継 `#M` を明記 |

**禁止**: 根拠のない close、推測のみの close、`ARCHITECTURE.md` 衝突を「wontfix」で逃げる close。

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
- **人間が reopen した場合**は `agent-closed` を外し、通常の選定対象に戻る

### ブロックとの違い

| | 対応せずクローズ | ブロック |
|--|------------------|----------|
| issue 状態 | **closed** | **open** |
| いつ | 対応不要と**確定**できる | 人間の判断・仕様決定が**未確定** |
| ラベル | `agent-closed` + `wontfix` 等 | `agent-blocked` |

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

| バグ・失敗テスト | `error-investigation` → `error-fix-red-green` |
| **TDD GREEN 後（実装経路・必須）** | [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) |

**必読**: `ARCHITECTURE.md`、`CLAUDE.md`、該当 issue 本文の「完了条件」「参照」。

## 3) ブランチ・実装（TDD）

- ブランチ: `issue/<number>-<short-slug>`（例: `issue/14-plans-task-schedules-in-json`）
- **TDD**: RED → `test-common` で確認 → GREEN（`tdd-on-edit`）
- スコープは issue の完了条件のみ（ついで修正禁止: `project-necessary-code-only`）
- 単発の層実装は `use-skills-on-edit` に従いサブエージェント委譲可
- **GREEN 確認後、PR を開く前に必ず §4 へ**（クリーンアップ・レビューをスキップしない）

## 4) 順次クリーンアップ・レビュー（必須・TDD 直後）

1 issue = **1 修正単位** とみなし、[`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) を **1 回完結**させる。Issue Worker 実行時は当該スキルの `disable-model-invocation` を**上書きして適用する**（TDD GREEN 後の必須ステップ）。

```
§3 改修（RED→GREEN 済み）
  → A デッドコード（触れた範囲）
  → B 責務外テスト（移動 or セーフ削除）
  → C 責務外コード（移動 or セーフ削除）
  → D レビュー（ARCHITECTURE 照合・test-common・test-slow-detection）
  → §5 へ
```

| ステップ | 要点 |
|----------|------|
| **A** | 当該 issue で変更したファイルと import / 呼び出し先に限定。到達不能のみ削除 |
| **B** | 誤レイヤ・重複・obsolete テストを移動 or セーフ削除。移動先で `test-common` GREEN |
| **C** | Component / Presenter / Gateway / Interactor の責務外を正しい層へ。移動は TDD |
| **D** | `ARCHITECTURE.md` 条項の短文記録 → 関連 spec 個別 GREEN → 層に応じた全体 `test-common` → `test-slow-detection` |

判定木・記録テンプレ: [`sequential-cleanup-review-workflow/references/CHECKLIST.md`](../sequential-cleanup-review-workflow/references/CHECKLIST.md)

**D が完了するまで PR を開かない。**

## 5) Issue 固有の確認

§4 のあと、issue 本文の完了条件に照らして追加確認する。

1. i18n issue: `ja` / `en` / `in` 同パス更新済み
2. デザインレビュー issue: キャプチャ・`visual-review-results.md` 更新が完了条件に含まれる場合のみ実施
3. issue の「完了条件」チェックリストを PR 本文用に写す

## 6) PR

```bash
gh pr create --title "fix: <issue タイトルから要約> (#<N>)" --body "$(cat <<'EOF'
## Summary
- <変更の要点>

## Issue
Closes #<N>

## Test plan
- [ ] TDD: 関連 spec RED→GREEN（test-common）
- [ ] 順次クリーンアップ・レビュー（A〜D）完了
- [ ] <層に応じた全体 test-common の結果>

## ARCHITECTURE レビュー（§4-D 要約）
- 触れた層: …
- 照合結果: 問題なし / 条項 #N（あれば）

## 完了条件（issue より）
- [ ] ...
EOF
)"
gh pr edit --add-label agent-merge
gh pr ready
```

- PR 本文に issue の完了条件チェックリストを写す
- `Closes #N` を含めマージ時に自動クローズ
- `agent-merge` で [`github-pr-merge-worker`](../github-pr-merge-worker/SKILL.md) がマージ候補に入る（**Draft のままでは dispatch しない** — `gh pr ready` 必須）

## 7) 終了

### 成功

issue コメントに PR URL。`agent-in-progress` を外し、付いていれば `agent-ready` も外す。

### ブロック（規約衝突・仕様不明・権限不足）

実装を増やさず issue に理由をコメント。`agent-in-progress` → `agent-blocked` に差し替え。PR は開かない。**issue は閉じない**（人間が reopen 不要で判断できるようにする）。

### 対象なし

オープン issue が選定条件を満たさない場合は **コミット・PR なし** で終了（Memory に「対象なし・日時」のみ記録可）。

## 8) 禁止

- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- `npm test` / `rails test` の直叩き（`test-common` 経由のみ）
- issue スコープ外のリファクタ・README 増殖
- 依存未完了 issue への着手
- 1 実行で複数 issue にまたがる PR
- `action: close_with_reason` 指定時の実装・PR
- 根拠なしの `gh issue close`
- **TDD GREEN 後に `sequential-cleanup-review-workflow`（§4）を省略して PR を開く**
- **クリーンアップ・レビューを PR 末にまとめる**

## 関連

- **UX/UI 起票の上流**: **`ux-issue-pipeline`**（キャプチャ・ビジュアルレビュー・`collect-ux-findings`）。デザイン系 issue の完了条件にキャプチャ再実行が含まれる場合は、実装後にパイプライン §6（フェーズ 1–2）を繰り返す。

## セットアップ（Cursor Automation）

詳細・prefill URL・トラブルシュート: [cloud-automation-audit/references/cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

prefill URL の **トリガーは UI 側で未対応のことがあり** `Invalid trigger` になる。トリガーは Automation 画面で手動追加する。

### 定期実行（Schedule）

1. [cursor.com/automations](https://cursor.com/automations) → Create Automation
2. **Repository**: `rick-chick/agrr`、branch `master`
3. **Trigger** → Schedule → Custom cron（**5 フィールド**）:
   - 式: `0 9 * * 1-5`
   - Timezone: `Asia/Tokyo`（平日 9:00 JST）
   - ※ `0 0 0 * * 1-5` のような 6 フィールド式は **Invalid trigger** になる
4. **Tools**: Pull request creation を有効化
5. **Prompt**（または prefill のプロンプト欄）:

```
You are the AGRR GitHub Issue Worker for repository rick-chick/agrr.
Read and follow `.cursor/skills/github-issue-worker/SKILL.md` exactly.
After TDD GREEN, always run `.cursor/skills/sequential-cleanup-review-workflow/SKILL.md` (§4) before opening a PR.
```

### 手動ディスパッチ（Webhook + GitHub）

1. 上記 Automation に **Webhook** トリガーを追加（保存後に URL / API key を取得）
2. GitHub Secrets: `CURSOR_ISSUE_WORKER_WEBHOOK_URL`, `CURSOR_ISSUE_WORKER_WEBHOOK_KEY`
3. issue にラベル付与 → `.github/workflows/issue-worker-dispatch.yml` が起動
   - `agent-ready` … 実装優先（`action: implement`）
   - `agent-close` … 理由付きクローズ優先（`action: close_with_reason`）


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
