---
name: github-pr-merge-worker
description: >-
  rick-chick/agrr の対象 PR を CI 通過後にレビューし、軽微な不備は同一ブランチで修正してから
  squash マージする。Cursor Automation（PR opened / CI completed / webhook）または手動で適用。
---

# GitHub PR Merge Worker（AGRR）

**1 回の実行 = 最大 1 PR**。対象 PR をマージ可能にし、条件を満たせば **squash マージ** する。

| 経路 | 結果 |
|------|------|
| **マージ** | CI green → レビュー合格 → 必要なら同一ブランチ修正 → `gh pr merge --squash` |
| **修正のみ** | CI / レビュー不備を同一ブランチで修正し push。**マージは次回 run（CI completed）に委譲** |
| **スキップ** | 対象外・人間レビュー待ち・マージ禁止ラベル → コメントまたは無言終了 |
| **ブロック** | 規約衝突・判断不能 → `agent-merge-blocked` ラベル + コメント（マージしない） |

## 設計方針（ベストプラクティス）

業界で一般的な **二層ゲート** に従う。

| 層 | 担当 | 本リポジトリ |
|----|------|--------------|
| **硬いゲート** | 必須 CI・ruleset | `rails-test` / `frontend-test` / `lint / frontend-lint`（ruleset **master CI required**） |
| **軽いゲート** | 差分レビュー・影響調査・テスト補完 | 本 Worker（Cloud Agent） |

**原則**

- PR open 直後にマージしない。**CI が green になるまで待つ**（`gh pr checks` ポーリング、または `CI completed` / Backend test `workflow_run` Webhook）。
- **オプトイン**: 全 PR 自動マージはしない。下記「対象 PR」のみ。
- マージは **GitHub native auto-merge に依存しない**。Agent が `gh pr merge --squash` を実行。
- 大規模変更・仕様判断・ARCHITECTURE 衝突は **マージせず** 人間へエスカレーション。
- **babysit 相当**（§5）: コメント triage、コンフリクト解消、**PR スコープ内** の CI 修正のみ。

### Cloud Agent の制約

[`cursor-automation-schedule.md`](../cloud-automation-audit/references/cursor-automation-schedule.md) と同様、**ローカル Docker / ng は使えない**。

| 変更種別 | Cloud での検証 | マージ判断の主根拠 |
|----------|----------------|-------------------|
| フロント | `.cursor/skills/test-common/scripts/run-test-frontend.sh`（個別ファイル可） | ローカル spec + **GitHub CI** |
| Rust domain | `cargo test -p agrr-domain`（該当 crate のみ） | **GitHub CI**（`rails-test` / `rust-domain-test`） |
| R4 契約（Docker） | **実行不可** | **GitHub CI `rails-test` が green** であることのみ |

バックエンド変更の bugfix でテスト追加が必要なとき、Cloud 上で RED/GREEN できない場合は **同一ブランチにテストを追加して push し、CI green を待つ**。マージは CI 通過後。

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（`Pull request opened`） | 対象 PR を選定 → CI 待ち → レビュー |
| Cursor Automation（`CI completed`） | **推奨**。対象 PR で CI 更新後に再評価 |
| Cursor Automation（webhook） | `.github/workflows/pr-merge-worker-dispatch.yml`（**Backend test 完了時** + PR opened / `agent-merge` label） |
| 手動 | 「PR #N をマージワーカー」「#123 をマージ可能にして」 |

Webhook payload フィールド: `repository`, `pr_number`, `pr_title`, `pr_url`, `action`（`opened` | `labeled` | `synchronize` | `ci_completed` | `conflict`）, `head_ref`, `head_sha`, `author`.

## 0) 着手前（重複 run 抑止）

```bash
gh pr view <N> --json labels,state,headRefOid
```

| 条件 | 動作 |
|------|------|
| ラベル `agent-merge-in-progress` が付いている（Webhook も dispatch しない） | **スキップ**（重複 Agent を起動しない） |
| ペイロード `head_sha` があり、現在の `headRefOid` と不一致（古い run） | **スキップ**（Memory に記録可） |
| 上記以外 | §1 へ |

着手時は直ちに `agent-merge-in-progress` を付与（§5）。**着手直後に `headRefOid` を Memory に記録**し、修正 push 後の再 run では新 SHA で再評価する。

## 1) 対象 PR（オプトイン）

次の **いずれか** を満たす PR のみ着手する。

| 条件 | 例 |
|------|-----|
| ラベル `agent-merge` | Issue Worker または人間が付与 |
| head ブランチが `issue/<number>-*`（正規表現 `^issue/[0-9]+-`） | Issue Worker 標準ブランチ |
| 本文に `Merge-Strategy: agent` | 明示オプトイン（1 行で可。§3a feature の「`agent-merge` 明示」と同義） |

### 除外（着手しない）

- **Draft**
- **Fork 由来**（Cursor は fork PR を実行できない — スキップして Memory に記録）
- ラベル `agent-no-merge` / `do-not-merge` / `wip` / `agent-merge-blocked`
- `changes requested` の未解消レビューがある
- ベースブランチが `master` 以外
- diff が **800 行超**（`gh pr diff --stat`）かつ `agent-merge` ラベルなし
- タイトルに `[WIP]` / `[DRAFT]`

```bash
gh pr view <N> --json isDraft,mergeable,reviewDecision,labels,headRefName,baseRefName,author,additions,deletions
```

## 2) CI 待ち・ゲート

```bash
gh pr checks <N> --watch --interval 30   # 最大 45 分想定（Backend test が長い）
```

| 状態 | 動作 |
|------|------|
| 必須チェック **pending** | 待機。45 分超でタイムアウト → PR コメント「CI 待ちタイムアウト」で終了 |
| 必須チェック **fail** | §5 修正ループへ（スコープ内のみ） |
| 必須チェック **pass** かつ `mergeable` が `MERGEABLE` | §3 へ |
| `mergeable` が `CONFLICTING` または `mergeStateStatus` が `DIRTY` | §5a コンフリクト解消へ（CI 待ち不要） |
| Webhook `action: conflict` | §5a へ（`master` push 後または synchronize で検出） |

**必須**（ruleset / `gh pr checks`。名前変更時は本表と ruleset を更新）:

| context | workflow |
|---------|----------|
| `rails-test` | Backend test |
| `frontend-test` | Frontend test |
| `lint / frontend-lint` | Lint |

**追加（軟ゲート — ruleset 未登録）**（diff に `crates/**` が含まれ、check が PR に表示されているとき — Agent が pass を確認。ruleset だけではマージはブロックされない）:

| context | workflow |
|---------|----------|
| `rust-domain-test` | Rust domain test |

いずれか **ruleset 必須**チェックが **fail / pending** ならマージしない。`rust-domain-test` が表示されているのに fail なら **マージしない**（`agent-merge-blocked` または修正ループ）。

## 3) 分類とレビュー

### 3a) PR 分類

| クラス | 判定 | マージ方針 |
|--------|------|------------|
| **bugfix** | `fix:` / `Fixes #` / issue ラベル `bug` / 本文に再現手順 | テストカバレッジ確認（§3b）必須 |
| **automation** | `.cursor/skills/` / `.github/workflows/` のみ | ARCHITECTURE 軽量チェック |
| **i18n** | `assets/i18n` / `[i18n]` | `ja`/`en`/`in` 同パス更新を確認 |
| **feature** | 上記以外・API 追加・UI 新規 | **Issue Worker 由来（`issue/<number>-*`）はマージ可**（上流で TDD + 順次クリーンアップ済み）。それ以外は **`agent-merge` ラベルまたは本文 `Merge-Strategy: agent`** の明示時のみ |
| **deps** | Dependabot / renovate | **非マージ**（別ポリシー推奨） |

### 3b) bugfix — カバレッジ・影響調査

1. **再現テストの有無**: 変更した振る舞いに対応する spec / contract test が diff に含まれるか。
   - 無い → **TDD**: RED を追加 → Cloud 制約内で確認（§ Cloud Agent の制約）→ push → **CI green を待つ**
2. **影響調査**: 変更シンボル・ファイルの呼び出し元を grep。フロントは `run-test-frontend.sh` で関連 spec を個別実行。
3. **回帰**: 失敗があれば §5 で修正。スコープ外の既存失敗は **マージせず** コメントで報告。

### 3c) ARCHITECTURE ゲート

次のパスに diff があるとき `ARCHITECTURE.md` 禁止 1–39 を短文照合（記録のみ。新規 P0 違反は **マージしない**）:

| 領域 | パス |
|------|------|
| Rust domain | `crates/agrr-domain/**` |
| Rust adapters | `crates/agrr-adapters-*/**` |
| R4 契約 | `crates/agrr-r4-contract/**` |
| HTTP edge | `crates/agrr-server/**` |
| フロント | `frontend/src/app/**`（`components → usecase → domain`） |

P0 例: Interactor 以外での永続化、Presenter / Gateway 境界違反 → `agent-merge-blocked`。

**記録テンプレ（§3c 実施時に PR コメントまたは Memory に残す）**:

```markdown
### ARCHITECTURE ゲート（PR #N）
- 触れた層: domain | adapters | r4-contract | server | frontend
- 照合: ARCHITECTURE.md 禁止 1–39
- 結果: 問題なし | P0 #<禁止番号>（理由 1 文）
```

`crates/agrr-r4-contract` または `crates/agrr-server` の API 形状変更は、Cloud で R4 Docker 検証不可のため **慎重に**。判断不能ならマージせず `agent-merge-blocked`。

### 3d) Issue Worker 由来 PR

head が `issue/<number>-*` のとき:

- 上流 [`github-issue-worker`](../github-issue-worker/SKILL.md) が TDD + [`sequential-cleanup-review-workflow`](../sequential-cleanup-review-workflow/SKILL.md) 済みとみなす
- PR 本文に `Closes #N` が無ければ **コメントで指摘**（単独ではブロックしない）
- 「順次クリーンアップ・レビュー（A〜D）完了」チェック未完了は **リスクとして認識**するが、**CI green + §3c 問題なし**ならマージ可
- diff **1200 行超**（additions + deletions）は Issue Worker 由来でも **人間確認**を推奨（自動マージしない）

## 4) マージ

全ゲート通過後:

```bash
gh pr merge <N> --squash --delete-branch
```

`--delete-branch` は PR 単位の指定（repo 既定が `delete_branch_on_merge: false` でも、この PR の head は削除される）。

マージ前に PR コメント（テンプレ）:

```markdown
## 🤖 PR Merge Worker: マージします

**分類**: bugfix | automation | i18n | feature
**CI**: 全必須チェック pass
**レビュー**: ARCHITECTURE 問題なし / 該当なし
**テスト**: 関連 spec / CI GREEN
**補足修正**: なし | 同一ブランチで N コミット（概要）
```

マージ後:

- ラベル `agent-merge` / `agent-merge-in-progress` を除去
- Memory に `PR #N merged YYYY-MM-DD` を記録

## 5) 修正ループ（マージ前・同一ブランチ）

[`error-fix-red-green`](../error-fix-red-green/SKILL.md) / [`tdd-on-edit`](../tdd-on-edit/SKILL.md) に従う。

| 問題 | 対応 |
|------|------|
| CI 失敗（本 PR 起因） | 最小修正 → push → **マージせず終了**（Backend test workflow_run で再 dispatch） |
| コンフリクト | §5a |
| Bugbot / 未解消コメント | 妥当な指摘のみ修正。不同意はコメントで理由 |
| テスト不足（bugfix） | テスト追加 → push → 再 CI |

**禁止**: workflow / 必須チェックの緩和、スコープ外リファクタ、ruleset 迂回。

着手時:

```bash
gh pr edit <N> --add-label agent-merge-in-progress
```

終了時（マージしなかった場合）:

```bash
gh pr edit <N> --remove-label agent-merge-in-progress
```

### 5a) コンフリクト解消（`action: conflict` または `mergeable` / `mergeStateStatus`）

**起動**: `.github/workflows/pr-merge-worker-dispatch.yml` が `master` push 後・PR `synchronize`・CI 完了時に `mergeable: CONFLICTING` を検出すると Webhook `action: conflict` を dispatch（**CI ゲートはスキップ**）。

1. **状態確認**

```bash
gh pr view <N> --json mergeable,mergeStateStatus,headRefName,headRefOid
```

`mergeable` が `UNKNOWN` のときは 2 秒間隔で最大 5 回ポーリング。

2. **自動マージ試行**（呼び出し元の作業ツリーを汚さない）

```bash
.cursor/skills/github-pr-merge-worker/scripts/resolve-pr-merge-conflicts.sh <N>
```

- exit `0` — `origin/master` を head にマージして push 済み。§2 CI 待ちへ（**マージはしない**）。
- exit `2` — 競合マーカー残存。stdout の `CONFLICT_FILES` を読み、下記手順で解消。
- exit `3` — 既に非コンフリクト。§2 へ。
- exit `1` — エラー。PR コメントして `agent-merge-blocked`。

スクリプトは **`git worktree`** で一時ディレクトリに head を checkout し、`git checkout` / `switch` を呼び出し元で使わない。

3. **手動解消**（exit `2` のとき）

一時 worktree で作業する（例）:

```bash
HEAD_REF=$(gh pr view <N> --json headRefName -q .headRefName)
WORKDIR=$(mktemp -d)
git fetch origin master "$HEAD_REF"
git worktree add --detach "$WORKDIR" "origin/$HEAD_REF"
cd "$WORKDIR"
# 競合ファイルを編集（<<<<<<< マーカーを除去）
git add -A
git commit -m "chore: resolve merge conflict with master (PR #<N>)"
git push origin "HEAD:$HEAD_REF"
git worktree remove --force "$WORKDIR"
```

**解消方針**

| 種別 | 方針 |
|------|------|
| 非重複行の両方変更 | 両方の意図を保持して統合 |
| 同一行の異なるロジック | **ブロック**（`agent-merge-blocked` + 理由コメント） |
| `package-lock.json` / `Cargo.lock` | 依存更新後に再生成（スコープ内のみ） |
| 生成物・マージコミットのみ | マージコミットを採用 |

4. **push 後**

- PR コメントに解消概要を記載
- `agent-merge-in-progress` を外す
- **CI green を待つ**（`workflow_run` で再 dispatch）。コンフリクト解消直後はマージしない

## 6) ブロック・スキップ

### ブロック（`agent-merge-blocked`）

- ARCHITECTURE P0 違反
- 仕様判断が必要（**非 Issue Worker** の feature で完了条件不明）
- Memory に同一 PR の **CI 修正失敗が 2 回連続**（`PR #N ci-fix-fail count=2` を記録してからブロック）

### スキップ

- 対象外 PR
- `agent-merge-in-progress` による重複抑止（§0）
- CI pending でタイムアウト前に run 終了

## 7) 禁止

- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- `npm test` / `rails test` 直叩き（`test-common` のみ。Cloud では §制約に従う）
- 対象外 PR のマージ
- CI 未完了でのマージ
- branch protection / ruleset の迂回
- fork PR の実行
- **1 実行で複数 PR をマージ**

## 8) セットアップ

詳細・prefill: [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

### GitHub ruleset（硬いゲート）

リポジトリ ruleset **master CI required**（`master` 向け）:

| context | 意味 |
|---------|------|
| `rails-test` | Backend test |
| `frontend-test` | Frontend test |
| `lint / frontend-lint` | Lint |

`strict_required_status_checks_policy: true`（head が最新 `master` より進んでいること）。

確認: `gh api repos/rick-chick/agrr/rulesets --jq '.[] | select(.name=="master CI required")'`

ラベル: `agent-merge`, `agent-no-merge`, `agent-merge-in-progress`, `agent-merge-blocked`

### Cursor Automation

**Trigger（推奨）**

1. **CI completed** — `rick-chick/agrr`
2. **Webhook** — GitHub Actions（Backend test 完了 + PR opened / `agent-merge`）
3. **Pull request opened** — 任意（CI 待ちの早期着手用。**Webhook と併用時は §0 で重複抑止**）

**Tools**: Comment on PR（Approvals ON）、PR creation OFF、Memories ON

### Webhook Secrets

`CURSOR_PR_MERGE_WEBHOOK_URL`, `CURSOR_PR_MERGE_WEBHOOK_KEY`

## 関連

- 上流: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- 監査: [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md)
