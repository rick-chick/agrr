# 架構負債解消ロードマップ 実装レビュー所見

- 対象: `architecture-remediation-roadmap.plan.md`（外部アタッチ）の T-001〜T-063
- レビュー実施日: 2026-04-20
- レビュー基準: ロードマップ §0.1（1 タスク = 1 PR）/ §0.3（自己判断の禁止）/ §10.3（受入基準）
- 対象ブランチ: `2026-03-25-nqo7`

## サマリ

| 区分 | 件数 | 備考 |
|---|---|---|
| 完了（要件通り） | 多数 | Phase 0（T-022b 含む）/ T-031〜T-036 / T-051〜T-054 / T-052 等（2026-04-20 時点でロードマップ主要項目を反映） |
| 完了（暫定・要フォロー） | 0 | **T-030b**: 同上分解済み。E2E は [`test/domain/cultivation_plan/interactors/plan_save_session_test.rb`](../../test/domain/cultivation_plan/interactors/plan_save_session_test.rb)。Mapper 8 / Gateway 2 の単体テストを追加済み（2026-04-20 フォローアップ）。 |
| 意図的未着手 | 3 | **T-041〜T-043**: `hotwire_removal_plan.md` の Angular 未移行画面が残るためゲート維持 |
| ロードマップ外の副作用 | 0 | T-022b は独立コミット方針に整理済み |

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

### 対処（→ T-022b）**【2026-04-20: 対処完了】**

1. 本来スコープの差分（T-012 / T-013 / T-014 / T-030 / CI 系 / ADR 系）を `git add -p` で選別してコミット。
2. rubocop `-A` 由来の純フォーマット差分は `style/apply-rubocop-omakase` 等の独立ブランチにまとめ、独立 PR として提出（全テスト GREEN 条件は T-022 と同じ）。
3. 今後は `rubocop -a`（safe）/ `-A`（unsafe）の区別、および touched-file スコープ（`bundle exec rubocop <file>...`）を CI 設定 PR では明示する。

上記方針に従い、**C01〜C11 のコミット分割 + T-022b スタイルコミットが実施済み**（詳細は完了計画 Phase 0）。

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

### 対処（→ T-030b）**【2026-04-20: Mapper / Gateway 分解まで完了】**

1. **Mapper**（`lib/domain/cultivation_plan/mappers/`）: Farm / Field / Crop / Pest / AgriculturalTask / Fertilize / Pesticide / InteractionRule。
2. **Gateway**（`lib/adapters/cultivation_plan/`）: `PlanCopyGateway`（計画・関連・タスクスケジュール複製）、`CropTaskScheduleBlueprintGateway`（ブループリント一括挿入）。
3. **Calculator**（`lib/domain/cultivation_plan/calculators/planning_date_calculator.rb`）: 通年/年次の日付・`normalize_decimal`。
4. **Orchestrator**: `PlanSaveSession#call` が上記を順に呼び出し。共有状態は `PlanSaveContext`。
5. E2E は `test/domain/cultivation_plan/interactors/plan_save_session_test.rb`。単体: `test/domain/cultivation_plan/mappers/*_test.rb`、`test/adapters/cultivation_plan/*_gateway_test.rb`、`test/domain/cultivation_plan/calculators/planning_date_calculator_test.rb`。

## 3. 作業残骸の untracked ファイル（解消済み）

### 事実

- レビュー時点で以下が `?? untracked` として残存:
  - `lib/domain/cultivation_plan/interactors/plan_save_session.rb`（§2 の試行錯誤で生成され、`module Domain / module Interactors / class PlanSaveSession` のインデントが不整合な壊れたコピー、約 1090 行）
- いずれのコードからも参照されておらず、テストも GREEN だが、リポジトリ衛生観点で削除すべき。

### 対処

- 本レビュー内で削除済み。

## 4. 軽微な自己判断（記録のみ）

- T-001 で `ARCHITECTURE.md` の見出し絵文字（🏗️ / 🎯 等）を一括除去。§0.3 「タスク本文に記載無き判断の禁止」に厳密には抵触。本質的な害は無いため**取り消しはしない**が、今後の改訂時は roadmap に明記する。

## 実装メモ: Phase C（T-030b）のコミット粒度

- **事実**: Mapper 抽出・Gateway 抽出・`PlanSaveSession` のオーケストレータ化を **単一コミット** にまとめた（例: `7bc8c5e`）。ロードマップ §0.1「1 タスク = 1 PR」とは齟齬がある。
- **方針**: 履歴の書き換え（`git reset` / `rebase -i` / `commit --amend` による再分割）は行わない。
- **今後**: T-030c 以降、`lib/domain/**/mappers` / `lib/adapters/**` への抽出を続ける場合は **抽出 1 レイヤー = 1 コミット**（または 1 PR）を原則とする。

## 残タスク（2026-04-20 更新）

### 継続（T-030b 深度）

- Mapper / Gateway / Calculator への抽出と層別テストの土台は完了。**残る深掘り**（例: Interactor への完全吸収、top-level 名残の解消）は別タスクとする。

### `app/services` 残存ファイル棚卸し（移設は未実施・T-055〜T-062 予約）

| ID | パス | 役割の要約 | 移設先候補レイヤー |
|---|---|---|---|
| T-055 | [`app/services/agrr_service.rb`](../../app/services/agrr_service.rb) | `agrr` CLI/デーモンとのプロセス実行・プロトコル | `lib/adapters/agrr/`（プロセス I/O Gateway） |
| T-056 | [`app/services/crop_ai_upsert_service.rb`](../../app/services/crop_ai_upsert_service.rb) | 作物マスタの AI 連携 Upsert | `lib/domain/crop/interactors/` + `lib/adapters/`（外部 API） |
| T-057 | [`app/services/crop_task_schedule_blueprint_create_service.rb`](../../app/services/crop_task_schedule_blueprint_create_service.rb) | ブループリント作成オーケストレーション | `lib/domain/.../interactors/` + 既存 Gateway 再利用 |
| T-058 | [`app/services/crop_task_schedule_blueprint_generator.rb`](../../app/services/crop_task_schedule_blueprint_generator.rb) | ブループリント生成ロジック | `lib/domain/`（ドメインサービス）または `lib/presenters/` |
| T-059 | [`app/services/crops/task_schedule_blueprint_deletion_service.rb`](../../app/services/crops/task_schedule_blueprint_deletion_service.rb) | ブループリント削除 | `lib/domain/crop/interactors/` |
| T-060 | [`app/services/fields_allocator.rb`](../../app/services/fields_allocator.rb) | 圃場面積割付 | `lib/domain/farm/` または `lib/domain/cultivation_plan/` |
| T-061 | [`app/services/pest_crop_association_service.rb`](../../app/services/pest_crop_association_service.rb) | 害虫・作物関連付け | `lib/domain/pest/interactors/` |

- **衛生**: `app/services/crop_schedule/` は空ディレクトリの残骸（git 管理外）。ワークスペースから削除済み。再出現した場合は削除してよい。

### Hotwire/Stimulus 撤去（§8）— **前提未達のため着手禁止**

- T-041〜T-043: `docs/planning/hotwire_removal_plan.md` の**未 Angular 化画面**が解消するまで保留（同ドキュメント末尾にゲート記載済み）。

### 完了済み（参照のみ）

- T-031〜T-034 / T-035（`crop_schedule` → domain / adapter / presenter）/ T-036（`deletion_undo` を **`lib/deletion_undo/`** へ移設し `app/services/deletion_undo/` を空に。完全な `Domain::DeletionUndo::Interactors` 再編は未実施でよい暫定整理）
- T-051 / T-052（`ApiService` 統合、`api-client.service.ts` 削除）/ T-053 / T-054
- T-022b（コミット境界整理）
- **T-062**（2026-04-21）: [`lib/domain/cultivation_plan/interactors/plan_copier.rb`](../../lib/domain/cultivation_plan/interactors/plan_copier.rb) + [`Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year`](../../lib/adapters/cultivation_plan/plan_copy_gateway.rb)。E2E/添付: [`test/domain/cultivation_plan/interactors/plan_copier_test.rb`](../../test/domain/cultivation_plan/interactors/plan_copier_test.rb)。Gateway 単体: `copy_private_plan_for_year` / `copy_attachments_for_plan_copy` を [`test/adapters/cultivation_plan/plan_copy_gateway_test.rb`](../../test/adapters/cultivation_plan/plan_copy_gateway_test.rb) に追加。

## 推奨継続順序

1. **T-055〜T-061**（`app/services` 残の段階的移設・1 ファイル 1 PR）。次の優先候補: **T-059**（[`app/services/crops/task_schedule_blueprint_deletion_service.rb`](../../app/services/crops/task_schedule_blueprint_deletion_service.rb)）
2. Angular 未移行画面の完了 → **T-041〜T-043**
