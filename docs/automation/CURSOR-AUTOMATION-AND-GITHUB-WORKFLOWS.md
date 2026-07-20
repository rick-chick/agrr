# Cursor Automation と GitHub Workflows — 全体俯瞰

AGRR では **Cursor Automation（Cloud Agent）** と **GitHub Actions** を組み合わせて、issue 実装・PR マージ・UX 監査などを自動化している。本ドキュメントは両者の**役割分担・データの流れ・ワークフロー一覧**を俯瞰する。

**目的**: 人間がラベルを付けたり UI で再開したりしなくても、パイプラインが **完了・再開・完遂**できること。設計原則の正本は [`.cursor/skills/automation-authoring/references/PRINCIPLES.md`](../../.cursor/skills/automation-authoring/references/PRINCIPLES.md)。

**運用設定の正本**（cron・prefill URL・secrets 登録手順）は [`.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md`](../../.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md)。本資料はアーキテクチャ説明に専念し、手順の重複は避ける。

---

## なぜ 2 つの仕組みか

| 層 | 担当 | 典型タスク |
|----|------|------------|
| **Cursor Automation** | Cloud Agent（LLM） | スキルに従った判断・コード変更・PR 作成・レビュー・マージ判断 |
| **GitHub Actions** | 決定的な機械処理 | CI テスト、イベント検知、webhook 中継、ラベル付与、`gh pr ready`、リトライ・reconcile |

**原則**: GitHub 上のイベントやゲート条件は Actions が機械的に処理し、**判断が要る作業だけ** Cursor Automation の webhook で Cloud Agent を起動する。Cloud Agent はリポジトリを clone して `.cursor/skills/` を読むが、**ローカル Docker / ng serve は使えない**。

---

## 全体アーキテクチャ

```mermaid
flowchart TB
  subgraph GitHub["GitHub（rick-chick/agrr）"]
    ISS[Issue / PR / Label / Merge]
    CI[CI Workflows<br/>Backend test / frontend-test / lint]
    DISP["Dispatch Workflows<br/>（webhook 中継・機械 prep）"]
    RETRY["Retry / Reconcile<br/>（15 分 cron）"]
    ISS --> DISP
    CI --> DISP
    CI --> PREP
    DISP --> WH
    RETRY --> WH
    PREP["PR Agent Prep<br/>（label + gh pr ready）"]
    ISS --> PREP
    CI --> PREP
    PREP --> DISP
  end

  subgraph Cursor["Cursor Cloud"]
    WH[Automation Webhook]
    CA[Cloud Agent Run]
    SK[.cursor/skills/*.md]
    WH --> CA
    CA --> SK
  end

  CA -->|git push / gh issue / gh pr| GitHub
```

**認証の二系統**（Cloud Agent 内）:

| 用途 | トークン | 設定場所 |
|------|----------|----------|
| `git clone` / `git push` / PR 作成 | Cursor GitHub App（`ghs_…`） | Cursor Dashboard → Integrations |
| `gh issue` / `gh pr comment` 等 | ユーザー PAT（`AGRR_GH_PAT`） | Cursor Dashboard → Cloud Agents → Secrets |

詳細は [cursor-automation-schedule.md § GitHub CLI 認証](../../.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md#github-cli-認証cloud-agent)。

---

## 主要パイプライン

### 1. Issue 実装 → マージ（メインループ）

```mermaid
sequenceDiagram
  participant GH as GitHub Issue/PR
  participant DISP as dispatch workflows
  participant DA as Delivery Agent
  participant PAP as pr-agent-prep.yml
  participant CI as Backend test 他

  GH->>DISP: issue / PR / CI イベント
  DISP->>DISP: 機械ゲート・選定（lib）
  DISP->>DA: webhook（repository + issue_number / pr_number、action なし）
  DA->>GH: 実装 Draft PR / 修正 / squash merge
  GH->>PAP: pull_request opened
  PAP->>GH: agent-merge（closingIssuesReferences あり時）+ gh pr ready
  CI->>DISP: Backend test 完了
  DISP->>DA: PR フェーズ webhook
```

| 段階 | 実行者 | 参照 |
|------|--------|------|
| 観測・判断・実装・マージ | Cursor **Delivery Agent** | [`delivery-agent/SKILL.md`](../../.cursor/skills/delivery-agent/SKILL.md) |
| issue 起動トリガ | **issue-worker-dispatch** | [`.github/workflows/issue-worker-dispatch.yml`](../../.github/workflows/issue-worker-dispatch.yml) |
| PR 起動トリガ | **pr-merge-worker-dispatch** | [`.github/workflows/pr-merge-worker-dispatch.yml`](../../.github/workflows/pr-merge-worker-dispatch.yml) |
| Draft → ready・直列キュー | **pr-agent-prep**（AI 不要） | [`.github/workflows/pr-agent-prep.yml`](../../.github/workflows/pr-agent-prep.yml) |
| 実装・マージ手順（参照） | `github-issue-worker` / `github-pr-merge-worker` スキル | Delivery Agent §0 が観測して読み分ける |

**対象**（Merge Worker）: `master` 向け同一リポジトリ PR は **既定で対象**（オプトアウト: `agent-no-merge` / `do-not-merge` / `wip` / `agent-merge-blocked`、fork、`CHANGES_REQUESTED`）。`agent-merge` ラベルは互換のため残すが必須ではない。

**リトライ**: `issue-worker-retry-dispatch.yml` / `pr-merge-worker-retry-dispatch.yml` が 15 分ごとに滞留を reconcile。primary dispatch が `cancelled` になった場合も再送する。

**PR Merge Worker retry の reconcile 前処理**（[`pr-merge-worker-retry-dispatch.mjs`](../../scripts/pr-merge-worker-retry-dispatch.mjs) の `reconcilePrep`）:

- 未リンク PR（`closingIssuesReferences` 空）→ `agent-no-merge` 付与（誤 `agent-merge` を是正）
- マージ済み PR と **同一タイトル** または **同一 closing issue** の open PR → 自動 close（[`pr-superseded-close-lib.mjs`](../../scripts/pr-superseded-close-lib.mjs)）

**機械層の本文パース禁止**・思想優先: [`.cursor/rules/automation-philosophy-priority.mdc`](../../.cursor/rules/automation-philosophy-priority.mdc)（正本 [PRINCIPLES.md](../../.cursor/skills/automation-authoring/references/PRINCIPLES.md)）。

**依存ゲート**: `implement` 経路は **`agent-deps:v1` コメントキャッシュ**（[`issue-worker-deps-agent-lib.mjs`](../../scripts/issue-worker-deps-agent-lib.mjs)）のみを根拠に hard 依存を判定する（本文 `#N` regex パース禁止）。キャッシュ欠落・`body_hash` 不一致時は [`issue-worker-deps-resolve.mjs`](../../scripts/issue-worker-deps-resolve.mjs) が Delivery Agent webhook（`body_hash` のみ）を起動し、コメント作成後に reconcile が再 dispatch する。

#### 必須 CI 失敗の自動救済（CI fix 経路）

必須 CI が FAIL のまま滞留すると、ready 化・マージが進まない。Delivery Agent が PR フェーズで同一ブランチ修正する（dispatch lib が内部で `ci_fix` 経路を選定。**payload に `action` は載せない**）。

| 層 | 回復経路 |
|----|----------|
| **Delivery Agent（PR フェーズ）** | 必須 CI FAIL + 非コンフリクト — [`github-pr-merge-worker`](../.cursor/skills/github-pr-merge-worker/SKILL.md) §5 |
| **起動** | `pr-merge-worker-dispatch`（Backend test 完了で FAIL 検知）または `pr-merge-worker-retry-dispatch`（15 分 reconcile） |
| **issue 実装** | open PR がある間は **再 dispatch しない**（二重実装防止） |

```mermaid
sequenceDiagram
  participant GH as PR (draft or ready)
  participant CI as Backend test 他
  participant PMD as pr-merge-worker-dispatch
  participant DA as Delivery Agent

  CI->>GH: 必須 CI FAIL
  PMD->>DA: webhook（pr_number のみ）
  DA->>GH: 同一ブランチで CI 修正 push
  CI->>GH: 必須 CI green
  Note over GH: ready ならマージ経路 / Draft なら pr-agent-prep が ready 化
```

### 2. UX キャンペーン（マージ後ループ）

PR マージ成功後、**Delivery Agent の同一 run** がリンク issue の `ux-campaign:breadcrumb` を見て post-merge（scan・残件起票）を実行する。

```
issue（ux-campaign:*）→ Delivery Agent（実装）→ PR → Delivery Agent（マージ + post-merge）→ 残件 issue（agent-ready）→ …
```

| 段階 | 実行者 | 参照 |
|------|--------|------|
| マージ + post-merge | Cursor **Delivery Agent** | [`delivery-agent/SKILL.md`](../../.cursor/skills/delivery-agent/SKILL.md) / [`ux-campaign-loop/SKILL.md`](../../.cursor/skills/ux-campaign-loop/SKILL.md) |

### 3. UX Issue Audit（週次・条件付き起票）

月曜 9:00 JST の **Cursor cron** で起動。リポジトリ上の `visual-review-results.md` を前提に CSS 監査・草案作成。**条件を満たすときだけ** issue 起票（実装 PR は Issue Worker 経由）。

| 段階 | 実行者 | 参照 |
|------|--------|------|
| 定期監査 | Cursor **UX Issue Audit** | [`ux-issue-pipeline/SKILL.md`](../../.cursor/skills/ux-issue-pipeline/SKILL.md) § Automation |
| 画面キャプチャ（非 Automation） | **frontend-e2e-capture** | [`.github/workflows/frontend-e2e-capture.yml`](../../.github/workflows/frontend-e2e-capture.yml) |

### 4. Automation Audit（週次・自己監査）

金曜 10:00 JST。Issue Worker / UX Audit の**GitHub 副作用**を間接監査し、repo 側のクリティカル不具合のみ PR を開く。

| 段階 | 実行者 | 参照 |
|------|--------|------|
| 監査 | Cursor **Automation Audit** | [`cloud-automation-audit/SKILL.md`](../../.cursor/skills/cloud-automation-audit/SKILL.md) |

### 5. Pipeline Watchdog（毎時・運用監視）

毎時 0 分 JST。issue / PR / dispatch workflow を機械収集し、P0/P1 異常を調査して **GitHub issue** 化（`automation-watchdog` ラベル）。週次 Audit とは補完関係。

| 段階 | 実行者 | 参照 |
|------|--------|------|
| 監視・起票 | Cursor **Pipeline Watchdog** | [`automation-pipeline-watchdog/SKILL.md`](../../.cursor/skills/automation-pipeline-watchdog/SKILL.md) |

### 6. Cleanup 外側ループ（手動・repository_dispatch）

大規模クリーンアップの機械的外側ループ。shell が backlog 管理し、**1 item ずつ** webhook で Cloud Agent を起動する（AI は item 実行のみ）。

| 段階 | 実行者 | 参照 |
|------|--------|------|
| dispatch | **cleanup-outer-loop-dispatch** | [`.github/workflows/cleanup-outer-loop-dispatch.yml`](../../.github/workflows/cleanup-outer-loop-dispatch.yml) |
| 手順 | shell + スキル | [`sequential-cleanup-review-workflow`](../../.cursor/skills/sequential-cleanup-review-workflow/SKILL.md) |

---

## GitHub Workflows 一覧

### A. CI / デプロイ（Cursor とは独立）

| Workflow | ファイル | トリガ | 役割 |
|----------|----------|--------|------|
| Backend test | [`rails-test.yml`](../../.github/workflows/rails-test.yml) | PR / master push | agrr-domain + R4 契約テスト。**Merge Worker の CI ゲートの正** |
| Frontend test | [`frontend-test.yml`](../../.github/workflows/frontend-test.yml) | reusable | Angular ユニットテスト |
| Lint | [`lint.yml`](../../.github/workflows/lint.yml) | reusable | frontend-lint 等 |
| Rust domain test | [`rust-domain-test.yml`](../../.github/workflows/rust-domain-test.yml) | PR | cargo テスト（補助） |
| Frontend E2E smoke | [`frontend-e2e-smoke.yml`](../../.github/workflows/frontend-e2e-smoke.yml) | PR | route-smoke |
| Frontend E2E capture | [`frontend-e2e-capture.yml`](../../.github/workflows/frontend-e2e-capture.yml) | 週次 cron | 全ルート PNG artifact（UX Audit の入力） |
| Frontend deploy | [`frontend-deploy.yml`](../../.github/workflows/frontend-deploy.yml) | master / PR | 本番フロントデプロイ |

### B. Dispatch（GitHub イベント → Cursor webhook）

| Workflow | ファイル | トリガ | 起動する Automation | Secrets |
|----------|----------|--------|---------------------|---------|
| Issue Worker Dispatch | [`issue-worker-dispatch.yml`](../../.github/workflows/issue-worker-dispatch.yml) | issue opened / labeled | **Delivery Agent** | `CURSOR_DELIVERY_WEBHOOK_*` |
| Issue Worker Retry | [`issue-worker-retry-dispatch.yml`](../../.github/workflows/issue-worker-retry-dispatch.yml) | 15 分 cron / cancelled retry / issue closed | **Delivery Agent** | 同上 |
| PR Merge Worker Dispatch | [`pr-merge-worker-dispatch.yml`](../../.github/workflows/pr-merge-worker-dispatch.yml) | PR イベント / Backend test 完了 | **Delivery Agent** | 同上 |
| PR Merge Worker Retry | [`pr-merge-worker-retry-dispatch.yml`](../../.github/workflows/pr-merge-worker-retry-dispatch.yml) | 15 分 cron / cancelled retry | **Delivery Agent** | 同上 |
| Cleanup Outer Loop | [`cleanup-outer-loop-dispatch.yml`](../../.github/workflows/cleanup-outer-loop-dispatch.yml) | workflow_dispatch / repository_dispatch | （個別 webhook） | `CLEANUP_OUTER_LOOP_WEBHOOK_*` |

※ deps キャッシュ miss 時の webhook も同一 `CURSOR_DELIVERY_WEBHOOK_*`（[`issue-worker-deps-resolve.mjs`](../../scripts/issue-worker-deps-resolve.mjs)）。

### C. 機械処理のみ（Cloud Agent を起動しない）

| Workflow | ファイル | 役割 |
|----------|----------|------|
| PR Agent Prep | [`pr-agent-prep.yml`](../../.github/workflows/pr-agent-prep.yml) | `cursor/*`・`issue/*` かつ `closingIssuesReferences` あり → `agent-merge`、直列 `gh pr ready`、未リンクは `agent-no-merge` |

---

## Cursor Automation 一覧

| Automation | トリガ種別 | スキル | PR を開くか |
|------------|------------|--------|-------------|
| **Delivery Agent** | Webhook（issue/PR dispatch workflows） | `delivery-agent` → 参照 `github-issue-worker` / `github-pr-merge-worker` / `ux-campaign-loop` | 可（実装時） |
| ~~Issue Worker~~ | — | `github-issue-worker` | **廃止**（Delivery に統合） |
| ~~PR Merge Worker~~ | — | `github-pr-merge-worker` | **廃止**（Delivery に統合） |
| ~~UX Campaign Loop~~ | — | `ux-campaign-loop`（参照スキル） | **廃止**（Delivery post-merge に統合） |
| **UX Issue Audit** | Schedule（月曜 9:00 JST） | `ux-issue-pipeline` § Automation | 不可（条件付き issue） |
| **Automation Audit** | Schedule（金曜 10:00 JST） | `cloud-automation-audit` | 可（クリティカル修正時のみ） |
| **Pipeline Watchdog** | Schedule（毎時 0 分 JST） | `automation-pipeline-watchdog` | 不可（異常時 issue・P0 のみ最小 PR） |

**GitHub Actions のみ**（Cursor Automation ではない）: PR Agent Prep、Retry dispatch、Frontend E2E capture。

---

## Webhook の流れ（共通パターン）

1. GitHub 上でイベント発生（issue ラベル、PR CI 完了など）
2. **Dispatch workflow** が `scripts/*-dispatch-lib.mjs` でゲート・選定（内部 `action` は lib 専用。**payload には載せない**）
3. 対象外なら skip（ログのみ）
4. 対象なら `post-cursor-webhook.mjs` で Delivery Agent の webhook URL へ JSON payload を送信
5. Delivery Agent が §0 で GitHub を観測し、参照スキルに従って実行

Delivery Agent payload（`action` **なし**）:

| フィールド | 例 | 意味 |
|------------|-----|------|
| `repository` | `rick-chick/agrr` | 必須 |
| `issue_number` | `323` | issue 起点 / PR の `closingIssuesReferences` |
| `pr_number` | `427` | PR / CI 起点 |
| `pr_unlinked` | `true` | `closingIssuesReferences` が空。`issue_number` なしで PR フェーズ dispatch（Agent は PR フェーズのみ） |
| `body_hash` | （deps のみ） | 依存判定 run。実装・PR 禁止 |
| `mergeable_state` 等 | （任意） | PR 観測ヒント。Agent は GitHub を正とする |

UX Campaign Loop 等、Delivery 以外の Automation は従来どおり個別 payload（`pr_number`, `campaign_id` 等）。

secrets 未設定時、issue dispatch は **exit 0 でスキップ**（切替後は設定漏れに注意）。PR dispatch も未設定時は exit 0。

---

## スキルと規約の関係

すべての Automation は **プロンプトで特定スキルを `exactly` 読む**よう指示される。スキルが TDD（[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)）、Clean Architecture（[`ARCHITECTURE.md`](../../ARCHITECTURE.md)）、テスト実行（[`test-common`](../../.cursor/skills/test-common/SKILL.md)）を定義する。

Cloud 起動時の bootstrap: [`.cursor/environment.json`](../../.cursor/environment.json) → `cloud-gh-auth.sh` で `AGRR_GH_PAT` を `gh` に注入。

---

## 関連リンク

| 資料 | 内容 |
|------|------|
| [cursor-automation-schedule.md](../../.cursor/skills/cloud-automation-audit/references/cursor-automation-schedule.md) | 設定手順・prefill・secrets・トラブルシュート（**運用正本**） |
| [Cursor Automations 公式](https://cursor.com/docs/cloud-agent/automations) | プロダクト仕様 |
| [delivery-agent/SKILL.md](../../.cursor/skills/delivery-agent/SKILL.md) | Delivery Agent（観測・分岐の正本） |
| [github-issue-worker/SKILL.md](../../.cursor/skills/github-issue-worker/SKILL.md) | Issue 実装の詳細（Delivery から参照） |
| [github-pr-merge-worker/SKILL.md](../../.cursor/skills/github-pr-merge-worker/SKILL.md) | PR マージの詳細（Delivery から参照） |
| [cloud-automation-audit/SKILL.md](../../.cursor/skills/cloud-automation-audit/SKILL.md) | 監査観点 |
| [automation-authoring/SKILL.md](../../.cursor/skills/automation-authoring/SKILL.md) | 新規 Automation / dispatch 追加時の設計規約 |
