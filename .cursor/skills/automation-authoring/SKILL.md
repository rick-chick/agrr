---
name: automation-authoring
description: >-
  AGRR に Cursor Automation と GitHub Actions dispatch / retry を新規追加・変更・修正するときの設計規約と手順。
  オートメーション作成、dispatch 修正、webhook 配線、retry reconcile 設計、独立レビュー委譲で適用。
disable-model-invocation: false
---

# Automation Authoring（AGRR）

**目的**: 人間のラベル付与・UI 再開なしで **完了・再開・完遂**する閉ループ。場合分けで止めず **全部拾う**（[PRINCIPLES.md](references/PRINCIPLES.md)）。

**GitHub 機械層** と **Cursor Cloud Agent** の閉ループを、壊れず・重複なく・観測可能に追加する。本スキルは**新規・変更・修正**時の設計ゲートに専念する。

**思想優先**: [PRINCIPLES.md](references/PRINCIPLES.md) と [automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc) を最小パッチより優先。

## フェーズ一覧

| Phase | 名称 | 成果物 |
|-------|------|--------|
| 0 | 着手前 | トリガー等 5 項目の一文 |
| 1 | 責任分界・設計固定 | 機械 / Agent 分担の確定 |
| 2 | 実装（TDD） | dispatch lib・workflow・unit GREEN |
| **3** | **独立レビュー（サブエージェント委譲）** | 観点 A〜H 判定・Go/No-Go |
| **4** | **修正ループ** | P0/P1 解消・再レビュー |
| 5 | E2E 検証 | 実データ・Actions ログ・副作用 |
| 6 | 影響チェック・登録 | チェックリスト・レジストリ |

**Phase 3〜4 は省略禁止**（1 行修正でも思想・ゲートに触れる変更は対象）。詳細: [REVIEW-PERSPECTIVES.md](references/REVIEW-PERSPECTIVES.md)。

## 適用

| 経路 | 例 |
|------|-----|
| 新規 Automation | Issue Worker 型の webhook パイプライン追加 |
| dispatch / retry **変更・修正** | ゲート追加、バグ修正、payload 整合、reconcile 拡張 |
| スキル + workflow 同時追加 | UX Campaign Loop 型 |
| オートメーション経路の**レビュー・監査** | 本文パース発見時は同一タスクで除去案を出す |

**適用外**: 既存 Automation の通常実行（各 Worker スキル）、週次監査（`cloud-automation-audit`）、毎時監視（`automation-pipeline-watchdog`）。

## Phase 0) 着手前（必須）

[`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc) を満たすまで実装に入らない。

次を **一文ずつ** 書けること（**Phase 3 レビュー依頼にそのまま貼る**）:

1. トリガー（GitHub イベント）
2. 起動条件（**既定は対象・オプトアウトで除外**。ラベル欠落で本筋が止まらないこと）
3. 起動手段（webhook 直接か、labeled 経由か — [§制約](references/GITHUB-ACTIONS-CONSTRAINTS.md)）
4. 終了条件（PR / close / block / Memory）
5. 滞留時の回復経路（retry reconcile / watchdog — **人間再開を前提にしない**）

**既存の同型経路を先に読む**（[EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md)）。同型があるのに別経路を発明しない。**既存の本文パースは写さない**（[automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc)）。

設計原則の正本: [PRINCIPLES.md](references/PRINCIPLES.md)。**判断基準（即決用）**: [JUDGMENT-CRITERIA.md](references/JUDGMENT-CRITERIA.md)。

### 修正・レビュー時の追加ゲート

[automation-philosophy-priority.mdc §着手前チェック](../../rules/automation-philosophy-priority.mdc) を満たすこと。

## Phase 1) 責任分界を固定する

| 層 | 担当 |
|----|------|
| **GitHub Actions** | イベント検知・**機械ゲート**・webhook 中継・ラベル・reconcile |
| **Cursor Automation** | **エージェント判定**・スキルに従う実装・コード変更・PR |

**本文パースは禁止。** 判断はエージェントが `gh` で行う。Actions / dispatch lib は機械ゲートのみ（[PRINCIPLES.md §機械ゲート](references/PRINCIPLES.md)）。

Actions から Cloud Agent を起動するときは **`postWebhook`（curl）が正**。`GITHUB_TOKEN` でラベル付与だけでは `issues: labeled` workflow は起動しない（詳細は [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md)）。

### 状態機械とラベル契約

issue / PR ラベルは **契約**。新ラベルを十分な根拠なく増やさない。

| ラベル | 意味 |
|--------|------|
| `agent-ready` | 実装キュー入り（依存未充足でも維持。ゲートが再判定） |
| `agent-in-progress` | Worker 着手中 |
| `agent-close` | 対応せずクローズ経路 |

- **依存未充足**は `agent-ready` 維持 + Agent がコメントのみで終了（機械層は dispatch を止めない）。別ラベルでキューから外さない
- 詳細: [PRINCIPLES.md §ラベル](references/PRINCIPLES.md)

## Phase 2) 実装（TDD）

1. **`scripts/*-dispatch-lib.mjs`** — pure function（候補選定・ゲート・payload）。`node --test` で RED → GREEN
2. **`.github/workflows/*-dispatch.yml`** — トリガー・ゲート・webhook 送信
3. **`scripts/verify-*-dispatch-workflow-lib.mjs`** — workflow 必須スニペットの契約テスト
4. **retry / reconcile** — 新規 dispatch にはほぼ必須（[PRINCIPLES.md §retry / §本筋と救済](references/PRINCIPLES.md)）
5. **`.cursor/skills/<name>/SKILL.md`** — Agent 側手順（[`skill-authoring.mdc`](../../rules/skill-authoring.mdc) 準拠）

ゲートロジックは **dispatch lib に一箇所**。retry 経路も同じ lib を使う。

**Phase 2 完了条件**: 関連 `node --test` が GREEN。まだ E2E・独立レビューは未完了としてよい。

## Phase 3) 独立レビュー（サブエージェント委譲・必須）

実装担当 Agent は **自分で「完了」と判断する前に**、独立レビュアーを起動する。

1. [REVIEW-PERSPECTIVES.md §3](references/REVIEW-PERSPECTIVES.md) のプロンプトをコピーし、Phase 0 の 5 項目・変更ファイル・目的を埋める
2. **Task ツール**で `subagent_type: generalPurpose` のサブエージェントに委譲する（実装担当と同一視点の自己レビューのみで代替しない）
3. レビュアーは [REVIEW-PERSPECTIVES.md §1](references/REVIEW-PERSPECTIVES.md) の観点 **A〜H** で Pass/Fail を付ける
4. 出力の **マージ Go / No-Go** を記録する（コメント・Memory・PR 本文のいずれか）

観点の定義・典型 Fail・対象ファイル一覧: [REVIEW-PERSPECTIVES.md](references/REVIEW-PERSPECTIVES.md)。

## Phase 4) 修正ループ

[REVIEW-PERSPECTIVES.md §4](references/REVIEW-PERSPECTIVES.md) に従う。

1. **No-Go** または P0/P1 Fail → 指摘どおり修正（思想違反は同一 PR で解消）
2. `node --test` 再実行。ゲート変更なら責任空白の回帰テストを追加
3. **差分のみ**サブエージェントに再委譲（R4）
4. **Go** になるまで繰り返す。同一観点で 3 ラウンド解消しない場合は Phase 1 に戻す

**Phase 4 完了条件**: 独立レビュアーの **マージ Go**（Conditional Go は Phase 6 で P2 を解消）。

## Phase 5) E2E 検証（マージ前必須）

unit test GREEN と独立レビュー Go のあとに実施する。

1. **実データ** — 対象 issue/PR で候補選定スクリプトを実行
2. **Actions ログ** — `Dispatched` / `Skip retry` / 期待 skipReason を確認
3. **副作用** — ラベル変化・webhook 起動・下流 Automation run のいずれかを観測

手順: [CHECKLIST.md §E2E](references/CHECKLIST.md)

## Phase 6) 影響チェック・レジストリ登録

[CHECKLIST.md §影響](references/CHECKLIST.md) を全項目確認する。**影響調査と実装修正は分離する**。

| 登録先 | 内容 |
|--------|------|
| [cursor-automation-audit/references/cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md) | 名前・cron・スキル・期待成果・プロンプト |
| [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) | パイプライン表への 1 行 |
| `.cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health-lib.mjs` | dispatch workflow 名（watchdog 対象） |
| `verify-skill-references.sh` | スキル path（audit bootstrap） |

## 禁止

- 根拠なしの経路変更、`GITHUB_TOKEN` ラベルだけで Agent 起動を期待する設計
- dispatch lib と SKILL で別ロジックのゲート、retry なしの新規 webhook パイプライン
- **人間のラベル付与・UI 再開・人間レビューを本筋の前提にする**
- **場合分けで起動をスキップし人間待ちになる設計**（[PRINCIPLES.md §全部拾う](references/PRINCIPLES.md)）
- 1 イベントで複数 Agent fan-out、SKILL だけで workflow / test 省略、watchdog 登録省略
- **機械層への本文パース**（新規・残置・温存）、**思想違反の最小パッチ**
- **パース・例外ラベルでエージェント起動を避ける設計**（[automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc)）
- **Phase 3 独立レビュー省略**、実装担当のみの自己レビューでマージ Go とする

## 関連

| 資料 | 内容 |
|------|------|
| [REVIEW-PERSPECTIVES.md](references/REVIEW-PERSPECTIVES.md) | **レビュー観点 A〜H・委譲プロンプト・修正ループ** |
| [PRINCIPLES.md](references/PRINCIPLES.md) | 設計原則の正本（人間介在なし完遂・ゲート・retry） |
| [JUDGMENT-CRITERIA.md](references/JUDGMENT-CRITERIA.md) | 判断の即決表 |
| [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md) | TOKEN・トリガー制約 |
| [CHECKLIST.md](references/CHECKLIST.md) | 影響・E2E・マージ前 |
| [EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md) | 読むべき既存経路 |
| [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) | 全体俯瞰 |
| [cursor-automation-audit/references/cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md) | 運用正本 |
| [skill-authoring.mdc](../../rules/skill-authoring.mdc) | SKILL.md の書き方 |
| [github-pr-merge-worker](../github-pr-merge-worker/SKILL.md) | PR 救済・マージ（全 PR 既定対象） |
