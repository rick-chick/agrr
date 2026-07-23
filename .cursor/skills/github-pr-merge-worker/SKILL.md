---
name: github-pr-merge-worker
description: >-
  rick-chick/agrr の PR を CI 通過後に Agent がゲートし、軽微な不備は同一ブランチで修正してから
  squash マージする。人間レビュー待ちを前提にしない。Cursor Automation または手動で適用。
---

# GitHub PR Merge Worker（AGRR）

**1 回の実行 = 最大 1 PR**。対象 PR をマージ可能にし、条件を満たせば **squash マージ** する。

| 経路 | 結果 |
|------|------|
| **マージ** | CI green → Agent ゲート（ARCHITECTURE 等）通過 → 必要なら同一ブランチ修正 → `gh pr merge --squash` |
| **修正のみ** | CI / Agent レビュー不備を同一ブランチで修正し push。**マージは次回 run（CI completed）に委譲** |
| **スキップ** | 重複 run・fork・観測で着手不要と判断したとき → コメントまたは無言終了 |
| **ブロック** | 規約衝突・判断不能 → コメント（マージしない） |

設計方針の上位原則: [JUDGMENT-CRITERIA.md](../automation-authoring/references/JUDGMENT-CRITERIA.md)（判断基準・正本）、[PRINCIPLES.md §目的](../automation-authoring/references/PRINCIPLES.md)（**人間介在なしで完遂**）。

**観測優先**: 毎 run 先頭で `gh` で PR 状態を読む。webhook payload はヒントのみ（`action` なし）。**ラベル名で skip しない。**

## 設計方針（ベストプラクティス）

業界で一般的な **二層ゲート** に従う。

| 層 | 担当 | 本リポジトリ |
|----|------|--------------|
| **硬いゲート** | 必須 CI・ruleset | `rails-test` / `frontend-test` / `lint / frontend-lint`（ruleset **master CI required**） |
| **軽いゲート** | 差分レビュー・影響調査・テスト補完 | 本 Worker（Cloud Agent） |

**原則**

- **既定は観測して救済**（master 同期・CI 修正・マージ）。人間レビュー待ちは前提にしない
- **マージは Agent が `gh pr merge --squash`**
- ARCHITECTURE 衝突等はマージせずコメント

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
| Cursor Automation（webhook） | dispatch workflow が webhook 中継 → 本 SKILL で観測・判断 |
| **Retry dispatch** | 15 分 reconcile が webhook **再送**（機械は merge/close を選ばない） |
| 手動 | 「PR #N をマージワーカー」 |

Webhook payload フィールド: `repository`, `pr_number`（任意: `pr_title`, `pr_url`, `head_ref`, `head_sha`, `author`, `mergeable_state`, `merge_state_status`, `retry_reason`）。**`action` は送らない・無視**（分岐は §0 の GitHub 観測）。

### コンフリクト解消経路（`mergeable_state` が `BEHIND` / `DIRTY` / `CONFLICTING`）

対象 PR が `BEHIND` / `DIRTY` / `CONFLICTING` のとき、PR `synchronize` / `ready_for_review` 等で `.github/workflows/pr-merge-worker-dispatch.yml` が webhook を dispatch する。**master push 直後の BEHIND/CONFLICT 救済**は `pr-merge-worker-retry-dispatch` の **reconcile**（15 分 cron + cancel/failure 時）が webhook を再送する（選定: `scripts/pr-merge-worker-needs-sync.mjs`）。

| 動作 | 説明 |
|------|------|
| **着手** | §0 → 直ちに `agent-merge-in-progress` → §5.1 コンフリクト解消 |
| **CI** | **マージ前ゲートはスキップ**（コンフリクト解消が先）。push 後は Backend test 完了で `ci_completed` が再 dispatch |
| **マージ** | コンフリクト解消 push のあと **次回 run** で §2〜§4（本 run ではマージしない） |

### 上流: PR Agent Prep（Draft ブロッカー解消）

Cursor Automation が作成する **Draft PR** は [`.github/workflows/pr-agent-prep.yml`](../../../.github/workflows/pr-agent-prep.yml) が機械処理する（AI 不要）。

| 処理 | 担当 |
|------|------|
| `agent-merge` 付与 | `pr-agent-prep`（`cursor/*`・`issue/*` かつ `closingIssuesReferences` あり） |
| 直列キュー（同時 ready は 1 件） | `pr-agent-prep` |
| `gh pr ready`（CI green 後） | `pr-agent-prep` |
| master 同期（`BEHIND` / `DIRTY` / `CONFLICTING`） | **本 Worker**（`resolve-pr-merge-conflicts.sh`） |
| マージ判定・squash | **本 Worker** |

本 Worker は **ready 済み**の PR を **マージ** する。リンク issue の Draft ready は prep。**未リンク Draft** は Agent が `gh pr ready` してから §2〜§4。**例外**: `BEHIND` / `DIRTY` / `CONFLICTING` では Draft でも着手（コンフリクト解消のみ）。**例外**: 必須 CI FAIL かつコンフリクトなしでは Draft/ready 問わず着手（§5 修正のみ）。

### 必須 CI 失敗経路（全 PR）

必須 CI が赤のまま滞留する責任空白を埋める経路（Draft 限定だった旧設計を廃止し、ready / `feat/*` 等も対象）。

| 条件（すべて） | 説明 |
|----------------|------|
| 必須 CI のいずれか **FAIL**（完了済み） | `rails-test` / `frontend-test` / `lint / frontend-lint` |
| **コンフリクトなし** | `mergeable: MERGEABLE` かつ `BEHIND` / `DIRTY` / `CONFLICTING` でない |
| **オプトアウトなし** | fork / `CHANGES_REQUESTED` 等の構造除外のみ |

| 動作 | 説明 |
|------|------|
| **起動** | `pr-merge-worker-dispatch`（`ci_completed` で FAIL 検知時）または retry reconcile（15 分 cron） |
| **着手** | §0 → `agent-merge-in-progress` → §5 修正ループ（同一ブランチで CI 修正） |
| **CI** | **マージ前ゲートはスキップ**（修正が先）。push 後は Backend test 完了で再評価 |
| **マージ** | **本 run ではマージしない**（CI green 後は通常 `ci_completed` / stuck_retry 経路） |

Issue Worker の open PR ゲートは**維持**（同一 issue の二重実装を防ぐ）。

## 0) 着手前（重複 run 抑止）

```bash
gh pr view <N> --json labels,state,headRefOid
```

| 条件 | 動作 |
|------|------|
| ラベル `agent-merge-in-progress` が付いている（Webhook も dispatch しない） | **スキップ**（重複 Agent を起動しない） |
| ペイロード `head_sha` があり、現在の `headRefOid` と不一致（古い run） | **スキップ**（コンフリクト解消経路は除く — コンフリクト解消 run は head が進むため） |
| payload `pr_unlinked`（optional） | **信用しない** — `gh pr view` で `closingIssuesReferences` を見て §0a か通常経路かを決める |
| 上記以外 | §1 へ（観測後） |

着手時は直ちに `agent-merge-in-progress` を付与（§5）。**着手直後に `headRefOid` を Memory に記録**し、修正 push 後の再 run では新 SHA で再評価する。

## 0a) PR 妥当性 — obsolete と行き先

コンフリクト解消・CI 修正・マージの前に実施。

```bash
gh pr view <N> --json title,body,state,mergeable,mergeStateStatus,closingIssuesReferences
gh pr diff <N> --name-only
gh pr list --state merged --base master --limit 30 --json number,title,mergedAt
```

| 観測 | 動作 |
|------|------|
| 同趣旨が **最近マージ済み** | **close** |
| 不要・方針外 | **close**（理由コメント） |
| 有効 | **§1 へ**（merge / 修正。オープン放置禁止） |
| 判断不能 | コメント + exit 0 |

**close 手順**（obsolete 確定時のみ）:

```bash
gh pr close <N> --comment "## 🤖 PR Merge Worker: obsolete

この PR はマージ済み #<M>（または方針変更）により陳腐化と判断したため close します。
再開する場合は新しい PR を開いてください。"
```

`agent-merge-in-progress` が付いていれば除去する。close 後は exit 0（マージ・コンフリクト解消に進まない）。

## 1) 対象 PR — Agent 観測後

`gh pr view` で観測し、§0a の後 **マージ・修正が妥当**と判断した PR のみ着手。

### 着手しない（観測結果）

- **Fork 由来**
- **`reviewDecision` が `CHANGES_REQUESTED`**
- ベースが `master` 以外
- **Draft**（リンク issue あり — prep 待ち。コンフリクト解消・CI 修正・未リンク merge 着手を除く）

未リンク PR（`closingIssuesReferences` 空）は prep 対象外。§0a 後は §1〜§4 と同じ。

```bash
gh pr view <N> --json isDraft,mergeable,reviewDecision,labels,headRefName,baseRefName,author,additions,deletions
```

## 2) CI 待ち・ゲート

```bash
gh pr checks <N> --watch --interval 30   # 最大 45 分想定（Backend test が長い）
```

| 状態 | 動作 |
|------|------|
| `mergeable_state` が `BEHIND` / `DIRTY` / `CONFLICTING` | §5.1 へ（CI 待ち・マージはしない） |
| 必須 CI **FAIL** かつコンフリクトなし | **CI 待ちをスキップ**（dispatch 側が FAIL 済みを確認）。§0 → §5 修正ループへ（マージはしない） |
| reconcile による再 dispatch（CI green 確認済み） | **CI 待ちをスキップ**。§0 の `agent-merge-in-progress` は **stale 除去後**の再 dispatch を想定 → §3 へ |
| `mergeStateStatus` が `BEHIND` | §5.1 へ（master 同期。CI 待ち不要） |
| 必須チェック **pending** | 待機。45 分超でタイムアウト → PR コメント「CI 待ちタイムアウト」で終了 |
| 必須チェック **fail** | §5 修正ループへ（スコープ内のみ） |
| 必須チェック **pass** かつ `mergeable` が `MERGEABLE` かつ `mergeStateStatus` が `BEHIND` でない | §3 へ |
| `mergeable` が `CONFLICTING` または `mergeStateStatus` が `DIRTY` | §5.1 コンフリクト解消へ（CI 待ち不要） |

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
| **feature** | 上記以外・API 追加・UI 新規 | **マージ可**（CI green + §3c 問題なし。`agent-merge` ラベルは不要） |
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
- `closingIssuesReferences` が空なら **コメントで指摘**（単独ではブロックしない）。本文の `Closes #N` 有無では判定しない
- 「順次クリーンアップ・レビュー（A〜D）完了」チェック未完了は **リスクとして認識**するが、**CI green + §3c 問題なし**ならマージ可
- diff **1200 行超**でも自動マージを止めない。判断不能・P0 のみ `agent-merge-blocked`（人間確認待ちを既定にしない — [automation-authoring PRINCIPLES](../automation-authoring/references/PRINCIPLES.md)）

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
- リンク issue に `ux-campaign:breadcrumb` があれば **同一 run で続行**し [`delivery-agent`](../delivery-agent/SKILL.md) §PR マージ成功後 → [`ux-campaign-loop`](../ux-campaign-loop/SKILL.md) §1〜§2

## 5) 修正ループ（マージ前・同一ブランチ）

[`error-fix-red-green`](../error-fix-red-green/SKILL.md) / [`tdd-on-edit`](../tdd-on-edit/SKILL.md) に従う。

| 問題 | 対応 |
|------|------|
| CI 失敗（本 PR 起因） | 最小修正 → push → **マージせず終了**（Backend test workflow_run で再 dispatch） |
| コンフリクト | §5.1 コンフリクト解消へ |
| Bugbot / 未解消コメント | 妥当な指摘のみ修正。不同意はコメントで理由 |
| テスト不足（bugfix） | テスト追加 → push → 再 CI |

**禁止**: workflow / 必須チェックの緩和、スコープ外リファクタ、ruleset 迂回。

### 5.1) コンフリクト解消（`mergeable_state` が `BEHIND` / `DIRTY` / `CONFLICTING`）

**起動**: `.github/workflows/pr-merge-worker-dispatch.yml` が `master` push 後・PR `synchronize`・CI 完了時に `mergeable: CONFLICTING` / `mergeStateStatus: DIRTY` を検出すると webhook を dispatch（**CI ゲートはスキップ**）。reconcile も同様に webhook 再送のみ。

**目的**: `master` 取り込み後のコンフリクトを同一ブランチで解消し push する。解消後は **マージせず終了**（CI green 後の `ci_completed` dispatch に委譲）。

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
- exit `3` — master 同期不要（`CLEAN` 等）。§2 へ。
- exit `1` — エラー。PR コメントして `agent-merge-blocked`。

スクリプトは **`git worktree`** で一時ディレクトリに head を checkout し、`git checkout` / `switch` を呼び出し元で使わない。

3. **手動解消**（exit `2` のとき、またはスクリプト未使用時）

```bash
gh pr edit <N> --add-label agent-merge-in-progress
gh pr checkout <N>
git fetch origin master
git merge origin/master
```

| 結果 | 動作 |
|------|------|
| **Fast-forward / 自動マージ成功**（コンフリクトマーカーなし） | 関連 spec を `test-common` で個別実行（変更ファイルに応じて）→ `git push` → PR コメント → `agent-merge-in-progress` を外して **終了** |
| **コンフリクトマーカーあり** | 下記ルールで解消 → テスト → commit → push → 終了 |
| **`git merge` 失敗（意図衝突）** | `git merge --abort` → `agent-merge-blocked` + 理由コメント → 終了 |

**マーカー解消の優先順位**（同一ファイル内）:

1. **両方の意図が必要**（例: 片方が i18n キー追加、片方が別キー追加）→ **両方残す**（重複キーは統合）
2. **PR 側が本修正・master が後追い** → PR の変更を軸に master の追加分を取り込む
3. **master が正（参照削除・リネーム済み）** → master 側を採用し、PR の差分を新構造に当て直す
4. **判断不能**（同一行の排他変更・仕様衝突）→ Agent がルール 1–3 で解消する。**真に両立不能**（ARCHITECTURE P0 衝突など）のみ `agent-merge-blocked`（人間が Web UI でマーカーを手直しする前提にしない）

**解消後**:

```bash
# コンフリクト解消済みファイルのみ add（意図的に git add -A しない）
git add <resolved-files...>
git commit -m "merge: sync with origin/master (resolve PR conflicts)"
# test-common で関連 spec GREEN
git push
```

PR コメント（テンプレ）:

```markdown
## 🤖 PR Merge Worker: コンフリクト解消

**経路**: conflict | ci_completed で検知
**mergeable_state**: CONFLICTING → MERGEABLE（または BEHIND 解消）
**解消方針**: 両方採用 | master 優先 | PR 優先
**テスト**: 関連 spec GREEN（test-common）
**次**: CI green 後に再 dispatch → マージ判断
```

**禁止**: `git rebase`（履歴改変で CI / review が混乱しやすい）、コンフリクト未解消の push、`<<<<<<<` マーカー残存。

着手時（コンフリクト以外の修正ループ）:

```bash
gh pr edit <N> --add-label agent-merge-in-progress
```

終了時（マージしなかった場合）:

```bash
gh pr edit <N> --remove-label agent-merge-in-progress
```

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

ラベル: `agent-merge-in-progress`（重複抑止のみ）。判断印ラベルで skip しない（[JUDGMENT-CRITERIA.md](../automation-authoring/references/JUDGMENT-CRITERIA.md)）。

### Cursor Automation

**正本**: [`delivery-agent/SKILL.md`](../delivery-agent/SKILL.md) §Automation。PR マージ・CI 修正は Delivery Agent §0 が GitHub を観測して本 SKILL を読む（専用 PR Merge Worker Automation は廃止）。

1. Automation 作成・secrets は `delivery-agent` と [cursor-automation-schedule.md §Delivery Agent](../cloud-automation-audit/references/cursor-automation-schedule.md) を参照
2. `.github/workflows/pr-merge-worker-dispatch.yml` が PR / Backend test 完了時に Delivery webhook を dispatch

### レガシー（ロールバック時のみ）

切替前の専用 PR Merge Worker（`CURSOR_PR_MERGE_*`、Cursor UI の CI completed / PR opened トリガー）は [cursor-automation-schedule.md §PR Merge Worker — レガシー](../cloud-automation-audit/references/cursor-automation-schedule.md) を参照。新規セットアップでは使わない。

## 関連

- 上流: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- 監査: [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md)
