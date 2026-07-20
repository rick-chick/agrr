---
name: automation-authoring
description: >-
  AGRR に Cursor Automation と GitHub Actions dispatch / retry を新規追加・変更・修正するときの設計規約と手順。
  オートメーション作成、dispatch 修正、webhook 配線、retry reconcile 設計で適用。
disable-model-invocation: false
---

# Automation Authoring（AGRR）

**目的**: 人間がラベル付与や UI 再開をしなくても、Automation が **完了・再開・完遂**できる閉ループを作る。場合分けで止まらせず **全部拾う**。詳細は [PRINCIPLES.md §目的 / §全部拾う](references/PRINCIPLES.md)。

**GitHub 機械層（Actions + scripts）** と **Cursor Cloud Agent（スキル + webhook）** の閉ループを、壊れず・重複なく・観測可能に追加する。

本スキルは既存 Automation の**通常実行手順を置き換えない**。**新規・変更・修正**時の設計ゲートと手順に専念する。

**思想優先**: 最小パッチより [PRINCIPLES.md](references/PRINCIPLES.md) と [automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc) を優先。提示する案は思想に沿ったものとする。

## 適用

| 経路 | 例 |
|------|-----|
| 新規 Automation | Issue Worker 型の webhook パイプライン追加 |
| dispatch / retry **変更・修正** | ゲート追加、バグ修正、payload 整合、reconcile 拡張 |
| スキル + workflow 同時追加 | UX Campaign Loop 型 |
| オートメーション経路の**レビュー・監査** | 本文パース発見時は同一タスクで除去案を出す |

**適用外**: 既存 Automation の通常実行（各 Worker スキル）、週次監査（`cloud-automation-audit`）、毎時監視（`automation-pipeline-watchdog`）。

## 0) 着手前（必須）

[`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc) を満たすまで実装に入らない。

次を **一文ずつ** 書けること:

1. トリガー（GitHub イベント）
2. 起動条件（**既定は対象・オプトアウトで除外**。ラベル欠落で本筋が止まらないこと）
3. 起動手段（webhook 直接か、labeled 経由か — [§制約](references/GITHUB-ACTIONS-CONSTRAINTS.md)）
4. 終了条件（PR / close / block / Memory）
5. 滞留時の回復経路（retry reconcile / watchdog — **人間再開を前提にしない**）

**既存の同型経路を先に読む**（[references/EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md)）。同型があるのに別経路を発明しない。**既存の本文パースは写さない**（[automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc)）。

設計原則の正本: [references/PRINCIPLES.md](references/PRINCIPLES.md)。

### 修正・レビュー時の追加ゲート

1. 提示案が PRINCIPLES の **目的・全部拾う・二層分離**に説明できるか
2. 差分・触れる近傍に **本文パース**が残っていないか（発見したら同一変更で除去）
3. **エージェント起動**で済む判断を機械層に置いていないか
4. コスト低減案が **本文パース・例外ラベル・dispatch 省略**に依存していないか（[PRINCIPLES.md §機械ゲート](references/PRINCIPLES.md)、[automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc)）

## 1) 責任分界を固定する

| 層 | 担当 |
|----|------|
| **GitHub Actions** | イベント検知・**機械ゲート**・webhook 中継・ラベル・reconcile |
| **Cursor Automation** | **エージェント判定**・スキルに従う実装・コード変更・PR |

**本文のパースは禁止。** 必要な判断はエージェントが `gh` で本文を読んで行う。Actions / dispatch lib は機械ゲートのみ（[PRINCIPLES.md §機械ゲートとエージェント判定](references/PRINCIPLES.md)）。

Actions から Cloud Agent を起動するときは **`postWebhook`（curl）が正**。`GITHUB_TOKEN` でラベル付与だけでは `issues: labeled` workflow は起動しない（詳細は [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md)）。

## 2) 状態機械とラベル契約

issue / PR ラベルは **契約**。新ラベルを十分な根拠なく増やさない。

| ラベル | 意味 |
|--------|------|
| `agent-ready` | 実装キュー入り（依存未充足でも維持。ゲートが再判定） |
| `agent-in-progress` | Worker 着手中 |
| `agent-close` | 対応せずクローズ経路 |

- **依存未充足**は `agent-ready` 維持 + dispatch 依存ゲート（`agent-deps:v1` のみ。本文パース禁止）。別ラベルでキューから外さない
- 詳細: [PRINCIPLES.md §ラベル](references/PRINCIPLES.md)

## 3) 実装（TDD）

1. **`scripts/*-dispatch-lib.mjs`** — pure function（候補選定・ゲート・payload）。`node --test` で RED → GREEN
2. **`.github/workflows/*-dispatch.yml`** — トリガー・ゲート・webhook 送信
3. **`scripts/verify-*-dispatch-workflow-lib.mjs`** — workflow 必須スニペットの契約テスト
4. **retry / reconcile** — 新規 dispatch にはほぼ必須（[PRINCIPLES.md §retry / §本筋と救済](references/PRINCIPLES.md)）
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
| `.cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health-lib.mjs` | dispatch workflow 名（watchdog 対象） |
| `verify-skill-references.sh` | スキル path（audit bootstrap） |

## 7) 禁止

- 根拠なしの経路変更（「たぶん labeled が飛ぶ」等）
- `GITHUB_TOKEN` ラベル付与だけで Agent 起動を期待する設計
- dispatch lib と SKILL で別ロジックのゲート
- retry なしの新規 webhook パイプライン
- **人間のラベル付与・UI 再開を本筋の前提にする**
- **人間レビューを安全ゲートにする**（「レビューがないと不十分だからオプトイン／承認必須」— 本リポジトリでは誤り）
- **事細かな場合分けで起動をスキップし、止まって人間待ちになる設計**（狭い例外を足すより全部拾う — [PRINCIPLES.md §全部拾う](references/PRINCIPLES.md)）
- 1 イベントで複数 Agent を fan-out
- SKILL だけ書いて workflow / test を省略
- 監査・watchdog 登録の省略
- **機械層への本文パース**（新規・残置・既存の温存。「動いている」は理由にならない）
- **思想違反の最小パッチ**（症状だけ直し、パースや責任空白を残す）
- **本文パース・ラベル省略でエージェント起動を避ける**（総コスト比較でエージェント起動を優先 — [PRINCIPLES.md §機械ゲート](references/PRINCIPLES.md)）
- **パース・例外ラベルでエージェントコストを下げる設計**（総コストが増える傾向 — [automation-philosophy-priority.mdc](../../rules/automation-philosophy-priority.mdc) §エージェントコストの低減）

## 関連

| 資料 | 内容 |
|------|------|
| [PRINCIPLES.md](references/PRINCIPLES.md) | 設計原則の正本（人間介在なし完遂・ゲート・retry） |
| [GITHUB-ACTIONS-CONSTRAINTS.md](references/GITHUB-ACTIONS-CONSTRAINTS.md) | TOKEN・トリガー制約 |
| [CHECKLIST.md](references/CHECKLIST.md) | 影響・E2E・マージ前 |
| [EXISTING-PATTERNS.md](references/EXISTING-PATTERNS.md) | 読むべき既存経路 |
| [CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md) | 全体俯瞰 |
| [cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md) | 運用正本 |
| [skill-authoring.mdc](../../rules/skill-authoring.mdc) | SKILL.md の書き方 |
| [github-pr-merge-worker](../github-pr-merge-worker/SKILL.md) | PR 救済・マージ（全 PR 既定対象） |
