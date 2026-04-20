# 架構負債解消ロードマップ 実装レビュー所見

- 対象: `architecture-remediation-roadmap.plan.md`（外部アタッチ）の T-001〜T-063
- レビュー実施日: 2026-04-20
- レビュー基準: ロードマップ §0.1（1 タスク = 1 PR）/ §0.3（自己判断の禁止）/ §10.3（受入基準）
- 対象ブランチ: `2026-03-25-nqo7`（作業途中、未コミット）

## サマリ

| 区分 | 件数 | 備考 |
|---|---|---|
| 完了（要件通り） | 18 | T-001〜T-003 / T-010〜T-015 / T-020〜T-023 / T-037 / T-040 / T-050 / T-060〜T-063 |
| 完了（暫定・要フォロー） | 1 | T-030（委譲のみで責務分割は未実施 → T-030b へ） |
| 未着手 | 14 | T-031〜T-036 / T-041〜T-043 / T-051〜T-054 |
| ロードマップ外の副作用 | 1 | rubocop `-A` 全リポジトリ適用（T-022b として分離） |

## 1. スコープ越境：rubocop `-A` の全リポジトリ適用

### 事実

- 作業完了時点の `git status` で **911 files modified / 25 deleted / 21 untracked**、`git diff --stat` で **935 files changed, 12,467 insertions(+), 16,444 deletions(-)**。
- 実質コード変更（T-012 / T-013 / T-014 / T-030 / CI 設定等）以外の大半は、以下の純スタイル修正:
  - 行末 whitespace 削除
  - シングルクォート → ダブルクォート統一
  - ファイル末尾改行の付与
  - 連続空行の詰め
  - Rakefile / `app/channels/` / `app/controllers/application_controller.rb` ほか、T-001〜T-063 で**言及されていないファイル**まで含む。

### ロードマップとの齟齬

- §0.1: **「1 タスク = 1 PR、スコープ越境を禁止」**
- §0.3: **「タスク本文に書かれていない自己判断は許可しない」**
- T-022 の本文は「CI workflow `lint.yml` を追加し `rubocop` / `brakeman` / `ng lint` を実行」であり、「既存コードへの autocorrect 一括適用」までは明示されていない。

### 対処（→ T-022b）

1. 本来スコープの差分（T-012 / T-013 / T-014 / T-030 / CI 系 / ADR 系）を `git add -p` で選別してコミット。
2. rubocop `-A` 由来の純フォーマット差分は `style/apply-rubocop-omakase` 等の独立ブランチにまとめ、独立 PR として提出（全テスト GREEN 条件は T-022 と同じ）。
3. 今後は `rubocop -a`（safe）/ `-A`（unsafe）の区別、および touched-file スコープ（`bundle exec rubocop <file>...`）を CI 設定 PR では明示する。

## 2. T-030 の受入基準の部分未達

### 事実

- ロードマップ §6 / T-030 本文は「`app/services/plan_save_service.rb` を `CultivationPlanCreateInteractor` **へ吸収**」。
- 実装は以下の妥協構成:
  - `app/services/plan_save_service.rb` → `app/services/plan_save_session.rb`（**top-level namespace、約1100行**のまま）へリネーム。
  - `lib/domain/cultivation_plan/interactors/cultivation_plan_create_interactor.rb` に class method `save_from_public_plan_session(user:, session_data:)` を新設し、`::PlanSaveSession.new(...).call` へ 1 行委譲。
  - `lib/domain/` 配下に Session を移動した試行時、`Farm` / `Crop` 等の ActiveRecord モデル参照が `Domain::Farm` に解決される Ruby の定数探索仕様で `NameError` 多発 → 断念し top-level に復帰。

### 影響

- Interactor の **エントリポイントは整備済み**（コントローラから Clean Architecture 側を経由するフローは達成）。
- ただし **内部 1100 行の手続きコードは責務分割されておらず**、§6 の「吸収」が意図する「責務分離された Interactor 群」には未到達。
- Rails 定数探索回避のための **top-level namespace** は Clean Architecture 原則から見れば暫定措置。

### 対処（→ T-030b）

1. `PlanSaveSession` を以下の責務に分割:
   - **Mapper**: セッションデータ → DTO / Entity 変換
   - **Gateway**: `Farm` / `Crop` / `Field` / `Fertilize` / `Pest` / `Pesticide` / `AgriculturalTask` / `InteractionRule` / `CultivationPlan` それぞれの永続化責務（ActiveRecord モデル参照はここに集約）
   - **Orchestrator（Interactor 本体）**: `lib/domain/cultivation_plan/interactors/` 配下。Gateway/Mapper を DI で受け取り、top-level モデルを直接参照しない。
2. `app/services/plan_save_session.rb` を削除、委譲 class method も不要化して純粋な `CultivationPlanCreateInteractor#execute` に統合。
3. 既存テスト（`test/services/plan_save_service_test.rb` 998 行）を Interactor / Gateway の単体テストへ分解移植。

## 3. 作業残骸の untracked ファイル（解消済み）

### 事実

- レビュー時点で以下が `?? untracked` として残存:
  - `lib/domain/cultivation_plan/interactors/plan_save_session.rb`（§2 の試行錯誤で生成され、`module Domain / module Interactors / class PlanSaveSession` のインデントが不整合な壊れたコピー、約 1090 行）
- いずれのコードからも参照されておらず、テストも GREEN だが、リポジトリ衛生観点で削除すべき。

### 対処

- 本レビュー内で削除済み。

## 4. 軽微な自己判断（記録のみ）

- T-001 で `ARCHITECTURE.md` の見出し絵文字（🏗️ / 🎯 等）を一括除去。§0.3 「タスク本文に記載無き判断の禁止」に厳密には抵触。本質的な害は無いため**取り消しはしない**が、今後の改訂時は roadmap に明記する。

## 残タスク（ロードマップ継続分）

### Rails: `app/services` 解体（§6）

- T-031: `cultivation_plan_creator.rb` + `cultivation_plan_optimizer.rb` → Interactor + `OptimizationGateway`
- T-032: `weather_prediction_service.rb` → `lib/domain/weather_data/interactors`
- T-033: `task_schedule_generator_service.rb` → `lib/domain/agricultural_task/interactors`
- T-034: `schedule_table_field_arranger.rb` の表示責務を Presenter / フロントへ
- T-035: `app/services/crop_schedule/*` 7 ファイル分解（契約準拠）
- T-036: `app/services/deletion_undo/*` 7 ファイル分解

### Hotwire/Stimulus 撤去（§8）

- T-041: root `package.json` の Hotwire / Stimulus / jest 依存削除
- T-042: `Gemfile` の `turbo-rails` / `stimulus-rails` / `jsbundling-rails` 削除
- T-043: `app/javascript/` と旧アセットパイプライン削除
  - 前提: `docs/planning/hotwire_removal_plan.md` に記載の未 Angular 化画面（Gantt / タスク／最適化など）の Angular 移行完了

### フロント整理（§9）

- T-051: `*-list-refresh.service.ts` 6 本 → ジェネリック `ListRefreshBus`
- T-052: `api.service.ts` と `api-client.service.ts` の一本化
- T-053: `frontend/src/app/infrastructure/` の処遇決定 + ARCHITECTURE 反映
- T-054: `app.routes.ts` を feature 別 `*.routes.ts` に分割

### 本レビューで追加

- T-022b: rubocop autocorrect 由来の全リポジトリスタイル変更を独立 PR へ分離
- T-030b: `PlanSaveSession` を gateway / orchestrator / mapper に責務分割し top-level namespace 回避を解消

## 推奨継続順序

1. **T-022b を最優先**でコミット境界整理（これ以降の PR 分離が困難になる前に実施）
2. T-031 / T-032 / T-033 を順次実施（§6 の残り Service 解体）
3. T-034 / T-035 / T-036（契約準拠を伴う分割、工数大）
4. T-030b（T-035/T-036 と同系統の重い作業）
5. T-051〜T-054（フロント整理、Rails 側と独立して並行可）
6. T-041〜T-043（Hotwire 撤去、Angular 未移行画面の完了後）
