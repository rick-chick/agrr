---
name: github-pr-merge-worker
description: >-
  rick-chick/agrr のオープン PR を 1 件選び、必須 CI 通過・レビュー・テスト確認後に squash マージする。
  bugfix はテストカバレッジと影響範囲分析を必須。Cursor Automation（pull_request ready_for_review / agent-merge ラベル）または手動で適用。
---

# GitHub PR Merge Worker（AGRR）

オープン PR のうち **1 件** を選び、次のいずれかで終了する。

| 経路 | 結果 |
|------|------|
| **マージ** | CI 全 pass → レビュー → コメント → squash merge |
| **スキップ** | 既にマージ済み / Draft / CI 未完了 / 必須チェック失敗 |
| **保留** | テスト不足・ARCHITECTURE 懸念・コンフリクト → コメントのみ（マージしない） |
| **対象なし** | マージ可能 PR なし → 何もしない |

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（`pull_request`） | `ready_for_review` で **その PR 番号を優先** |
| Cursor Automation（`pull_request`） | `labeled: agent-merge` で **その PR 番号を優先** |
| 手動 | ユーザーが「PR #N をマージ」「マージワーカー実行」等と依頼 |

## 1) 選定（1 回の実行 = 最大 1 PR）

### Webhook / Automation 起動時

ペイロードまたはプロンプトに PR 番号がある場合は **その PR のみ** を対象とする。

### 除外（マージしない）

- **既に `MERGED` / `CLOSED`**
- **Draft**（`isDraft: true`）
- **必須 CI チェック未完了**（`status: IN_PROGRESS` / `QUEUED` / `PENDING`）
- **必須 CI チェック失敗**（`conclusion: FAILURE` / `CANCELLED` / `TIMED_OUT`）
- **mergeable: CONFLICTING**（コンフリクト未解消）
- レビュー必須設定で **未承認**（repo 設定に従う）

### 手動選定（番号なし時）

```bash
gh pr list --repo rick-chick/agrr --state open --label agent-merge --json number,title,isDraft,statusCheckRollup
```

`agent-merge` ラベル付き PR を **番号昇順** で 1 件選ぶ。なければ `is:ready-for-review` で CI 全 pass の PR を番号昇順で 1 件。

## 2) 必須 CI チェック

マージ前に **すべて SUCCESS**（または SKIPPED で問題ないもの）であること。

| チェック名 | ワークフロー | 必須 |
|------------|--------------|------|
| `rails-test` | Backend test | ✅ |
| `frontend-test` | Frontend test | ✅ |
| `frontend-lint` | Lint | ✅ |
| `lint / frontend-lint` | Frontend deploy | ✅ |
| `GitGuardian Security Checks` | — | ✅ |
| `build-and-deploy` | Frontend deploy | SKIPPED 可（PR 時） |
| `check-deploy-secrets` | Frontend deploy | ✅ |
| `rust-domain-test` | Rust domain test | 変更に Rust 触れる場合 ✅ |

```bash
gh pr checks <N>
gh pr view <N> --json statusCheckRollup,mergeable,isDraft,state
```

**IN_PROGRESS のチェックがある間はマージしない。** 完了を待つか、タイムアウト時は Memory に記録して終了。

## 3) レビュー（マージ前必須）

### 3a) 分類

PR タイトル・本文・変更ファイルから分類:

| 分類 | 判定 |
|------|------|
| **bugfix** | `fix:` / `Closes #N`（bug ラベル issue）/ 表示不具合・キー欠損 |
| **i18n** | `assets/i18n` / `[i18n]` / locale catalog spec |
| **test** | テスト追加のみ |
| **feature** | 新機能・振る舞い追加 |
| **docs** | ドキュメント・スキルのみ |

### 3b) ARCHITECTURE ゲート

変更ファイルを読み、`ARCHITECTURE.md` 禁止 1–39 と照合。

- 触れた層を列挙（frontend / lib/domain / app/adapters 等）
- 問題なし / 懸念あり を判定
- **懸念あり** → §7 保留（マージしない）

### 3c) bugfix 追加要件（必須）

**bugfix または i18n bugfix** の場合:

1. **テストカバレッジ**: 修正した振る舞いを検証する spec / contract test が PR に含まれること
2. **影響範囲分析**: 変更ファイルと呼び出し元を確認し、副作用がないことを PR コメントに記載

```bash
gh pr diff <N> --name-only
# 関連 spec の存在確認（例: locale catalog spec, component spec）
```

テストが PR 本文に「追加済み」とあっても **diff に spec ファイルが無い** 場合は保留。

## 4) マージ手順

### 4a) マージ前コメント（必須）

```bash
gh pr comment <N> --body-file /tmp/pr-merge-worker.md
```

コメント形式:

```markdown
## 🤖 PR Merge Worker: マージします

**分類**: <bugfix|i18n|test|feature|docs>
**CI**: 全必須チェック pass（rails-test / frontend-test / lint / frontend-lint）
**レビュー**: ARCHITECTURE 問題なし（<触れた層の要約>）
**テスト**: <追加・確認した spec 名>
**影響範囲**: <bugfix の場合: 変更コンポーネントと呼び出し元の要約>
**補足修正**: なし / <あれば>

### ARCHITECTURE ゲート（PR #<N>）
- 触れた層: …
- 照合: ARCHITECTURE.md 禁止 1–39
- 結果: 問題なし
```

保留の場合は「マージしません」に変え、理由を記載。

### 4b) squash merge

```bash
gh pr merge <N> --squash --delete-branch
```

- **1 実行 1 PR** — マージ後は他 PR に進まない
- force push / rebase merge は使わない

## 5) 終了

### 成功（マージ完了）

- PR が `MERGED` であることを確認
- 紐づく issue（`Closes #N`）がクローズされていることを確認
- Memory に「#N merged・日時・分類」を記録

### スキップ（既にマージ済み）

トリガー PR が既に `MERGED` の場合:

- マージ操作は行わない
- 事後検証（CI・テスト・ARCHITECTURE）を実施し Memory に記録
- 必要なら「既にマージ済み・検証 OK」コメントは **重複を避けて省略可**

### 保留

PR に理由コメント。マージしない。Memory に記録。

### 対象なし

マージ可能 PR が無い場合は **コミット・マージなし** で終了。

## 6) 禁止

- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- CI 未完了・失敗状態でのマージ
- 1 実行で複数 PR のマージ
- Draft PR のマージ
- ARCHITECTURE 懸念を無視したマージ
- bugfix でテストカバレッジ未確認のマージ
- `npm test` / `rails test` の直叩き（ローカル検証が必要な場合は `test-common` 経由）

## 関連

- Issue 実装: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- クリーンアップ・レビュー: [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md)
- Automation 監査: [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md)

## セットアップ（Cursor Automation）

### Webhook トリガー

1. [cursor.com/automations](https://cursor.com/automations) → Create Automation
2. **Repository**: `rick-chick/agrr`、branch `master`
3. **Trigger** → Pull request → `ready_for_review` および `labeled`（`agent-merge`）
4. **Tools**: Pull request creation は OFF（マージのみ）
5. **Prompt**:

```
You are the AGRR GitHub PR Merge Worker for repository rick-chick/agrr.

Read and follow `.cursor/skills/github-pr-merge-worker/SKILL.md` exactly.

One PR per run. Never merge before required CI checks pass. For bugfixes, verify test coverage and run impact analysis before merging.
```

### ラベル

Issue Worker が PR を開いた後、レビュー準備完了時に `agent-merge` を付与:

```bash
gh pr edit <N> --add-label agent-merge
gh pr ready <N>   # Draft の場合
```

ラベル `agent-merge` が無い場合は作成:

```bash
gh label create agent-merge --description "PR Merge Worker may squash-merge after CI" --color 0E8A16
```
