---
name: automation-authoring
description: >-
  AGRR に Cursor Automation と GitHub Actions dispatch / retry を新規追加・変更するときの設計規約と手順。
  オートメーション作成、dispatch workflow 追加、webhook 配線、retry reconcile 設計で適用。
disable-model-invocation: false
---

# Automation Authoring（AGRR）

**GitHub 機械層（Actions + scripts）** と **Cursor Cloud Agent（スキル + webhook）** の閉ループを、壊れず・重複なく・観測可能に追加する。

本スキルは既存 Automation の**実行手順を置き換えない**。新規追加・変更時の設計ゲートと手順に専念する。

## 適用

| 経路 | 例 |
|------|-----|
| 新規 Automation | Issue Worker 型の webhook パイプライン追加 |
| dispatch / retry 変更 | ゲート追加、`issues: closed` トリガー、reconcile 拡張 |
| スキル + workflow 同時追加 | UX Campaign Loop 型 |

**適用外**: 既存 Automation の通常実行（各 Worker スキル）、週次監査（`cloud-automation-audit`）、毎時監視（`automation-pipeline-watchdog`）。

## 0) 着手前（必須）

[`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc) を満たすまで実装に入らない。

次を **一文ずつ** 書けること:

1. トリガー（GitHub イベント）
2. 起動条件（ラベル・状態・ゲート）
3. 起動手段（webhook 直接か、labeled 経由か — [§制約](references/GITHUB-ACTIONS-CONSTRAINTS.md)）
4. 終了条件（PR / close / skip / Memory）
5. 滞留時の回復経路（retry reconcile / watchdog）

**既存の同型経路を先に読む**（[references/EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md)）。同型があるのに別経路を発明しない。

## 1) 責任分界を固定する

| 層 | 担当 |
|----|------|
| **GitHub Actions** | イベント検知・ゲート・webhook 中継・ラベル・reconcile |
| **Cursor Automation** | スキルに従う判断・コード変更・PR |

Actions から Cloud Agent を起動するときは **`postWebhook`（curl）が正**。`GITHUB_TOKEN` でラベル付与だけでは `issues: labeled` workflow は起動しない（詳細は [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md)）。

## 2) 状態機械とラベル契約

issue / PR ラベルは **契約**。新ラベルを安易に増やさない。

| ラベル | 意味 |
|--------|------|
| `agent-ready` | 実装キュー入り |
| `agent-skipped` | 意図的スキップ（オープン維持） |
| `agent-in-progress` | Worker 着手中 |
| `agent-blocked` | 人間判断待ち |
| `agent-close` | 対応せずクローズ経路 |

- **待ち行列**（依存未充足など）と **スキップ**（対応不要）は別経路にする
- 一時保留に `agent-skipped` を使わない（reconcile の `RETRY_BLOCK_LABELS` から除外される）
- 詳細: [PRINCIPLES.md §ラベル](references/PRINCIPLES.md)

## 3) 実装（TDD）

1. **`scripts/*-dispatch-lib.mjs`** — pure function（候補選定・ゲート・payload）。`node --test` で RED → GREEN
2. **`.github/workflows/*-dispatch.yml`** — トリガー・ゲート・webhook 送信
3. **`scripts/verify-*-dispatch-workflow-lib.mjs`** — workflow 必須スニペットの契約テスト
4. **retry / reconcile** — 新規 dispatch にはほぼ必須（[PRINCIPLES.md §retry](references/PRINCIPLES.md)）
5. **`.cursor/skills/<name>/SKILL.md`** — Agent 側手順（[`skill-authoring.mdc`](../../rules/skill-authoring.mdc) 準拠）

ゲートロジックは **dispatch lib に一箇所**。retry 経路も同じ lib を使う。

## 4) E2E 検証（マージ前必須）

unit test GREEN だけでは完了にしない。

1. **実データ** — 対象 issue/PR で候補選定スクリプトを実行
2. **Actions ログ** — `Dispatched` / `Skip retry` / 期待 skipReason を確認
3. **副作用** — ラベル変化・webhook 起動・下流 Automation run のいずれかを観測

手順: [CHECKLIST.md §E2E](references/CHECKLIST.md)

## 5) 他オートメーション影響チェック

[CHECKLIST.md §影響](references/CHECKLIST.md) を全項目確認する。

**影響調査と実装修正は分離する**。調査依頼中に未検証の経路変更を入れない。

## 6) レジストリ登録

| 登録先 | 内容 |
|--------|------|
| [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md) | 名前・cron・スキル・期待成果・プロンプト |
| [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) | パイプライン表への 1 行 |
| `collect-pipeline-health-lib.mjs` | dispatch workflow 名（watchdog 対象） |
| `verify-skill-references.sh` | スキル path（audit bootstrap） |

## 7) 禁止

- 根拠なしの経路変更（「たぶん labeled が飛ぶ」等）
- `GITHUB_TOKEN` ラベル付与だけで Agent 起動を期待する設計
- dispatch lib と SKILL で別ロジックのゲート
- retry なしの新規 webhook パイプライン
- 1 イベントで複数 Agent を fan-out
- SKILL だけ書いて workflow / test を省略
- 監査・watchdog 登録の省略

## 関連

| 資料 | 内容 |
|------|------|
| [PRINCIPLES.md](references/PRINCIPLES.md) | 設計原則の正本 |
| [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md) | TOKEN・トリガー制約 |
| [CHECKLIST.md](references/CHECKLIST.md) | 影響・E2E・マージ前 |
| [EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md) | 読むべき既存経路 |
| [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) | 全体俯瞰 |
| [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md) | 運用正本 |
| [skill-authoring.mdc](../../rules/skill-authoring.mdc) | SKILL.md の書き方 |
