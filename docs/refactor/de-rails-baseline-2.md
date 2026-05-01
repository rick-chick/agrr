# de-rails-complete-remaining ベースライン (t20)

実行日: 2026-04-30
基線テスト: `run-test-rails.sh` → `1613 runs, 8070 assertions, 0 failures, 0 errors, 9 skips` (緑)

## 違反箇所サマリ (rg ベース、生カウント)

### (a) Controller / Concern AR 直叩き / association

`app/controllers` 配下の AR モデル定数 (`::Crop` / `::Farm` / `::Field` / `::Pest` / `::Pesticide` / `::Fertilize` / `::AgriculturalTask` / `::InteractionRule` / `::CultivationPlan` / `::FieldCultivation` / `::TaskSchedule` / `::TaskScheduleItem` / `::CropTaskTemplate` / `::CropTaskScheduleBlueprint` / `::DeletionUndoEvent` / `::CropPest` / `::CropStage`) 参照: 約 **350+ 行**（クラス参照を含む生カウント、実際の AR 直接操作はこのうち約 **160 行**）。

主な集中箇所:

- `app/controllers/api/v1/masters/`* 系: 各 17–24 件（テスト用 mocks 含む）
- `app/controllers/agricultural_tasks_controller.rb`: 17 件
- `app/controllers/farms_controller.rb`: 18 件
- `app/controllers/fields_controller.rb`: 16 件
- `app/controllers/crops_controller.rb`: 14 件
- `app/controllers/pesticides_controller.rb`: 14 件
- `app/controllers/concerns/cultivation_plan_api.rb`: 2 (rg) / 実体 40+
- `app/controllers/concerns/agrr_optimization.rb`: 1 (rg) / 実体 transaction/upsert_all 含む

`current_user.x.{find|where|build|create|update|destroy}` パターン: 8 ファイル

- `farms_controller.rb`: 2、`agricultural_tasks_controller.rb`: 1、`farms/weather_data_controller.rb`: 1、`plans_controller.rb`: 1、`api/v1/plans_controller.rb`: 1、その他 auth 系 2

`Gateway.default | Gateway.new` を controller で呼ぶケース: **0** (前計画 t1–t4 で解消済)。

### (b) `lib/domain` 内の AR 定数参照

**0** (前計画で除去済)。

### (c) `lib/domain` 内の `ActiveRecord::` 参照

5 ファイル:

- `lib/domain/shared/dtos/query_dto.rb`: コメントのみ
- `lib/domain/shared/dtos/user_dto.rb`: コメントのみ
- `lib/domain/shared/exceptions/association_in_use.rb`: 例外定義のドキュメント
- `lib/domain/shared/exceptions/record_not_found.rb`: 同上
- `lib/domain/shared/policies/policy_permission_denied.rb`: 同上

→ いずれもコメント / 例外説明のみ。実コード参照ゼロ。

### (d) `rescue ActiveRecord::`* (controllers + lib/domain)

`lib/domain`: **0** (純粋)。
`app/controllers`: 27 ファイルで残存。主なもの:

- `concerns/cultivation_plan_api.rb`: 4
- `plans_controller.rb`: 6
- `public_plans_controller.rb`: 4
- `crops/`* 配下: 7
- `api/v1/masters/crops/*`: 7
- `concerns/deletion_undo_flow.rb`: 1
- `concerns/cultivation_plan_manageable.rb`: 1

### (e) `form_with model: @ar` (Form Object 化が必要)

12 ファイル:

- `farms/{new,edit}.html.erb` (2)
- `fields/{new,edit}.html.erb` (2)
- `agricultural_tasks/_form.html.erb` (1)
- `crops/agricultural_tasks/edit.html.erb` (1)
- `pests/_form.html.erb` (1)
- `crops/pests/_form.html.erb` (1)
- `interaction_rules/_form.html.erb` (1)
- `fertilizes/_form.html.erb` (1)
- `pesticides/_form.html.erb` (1)
- `crops/_form.html.erb` (depth-2 nested、別途）

`accepts_nested_attributes_for` を持つ AR モデル: 4 (`crop`, `crop_stage`, `pest`, `pesticide`)。

### (f) `find_authorized_model_for_*` が public のままの Adapter Gateway

7 ドメイン (各 2 メソッド = 計 14 サイト):

- `pest_memory_gateway.rb`: 2
- `pesticide_active_record_gateway.rb`: 2
- `fertilize_active_record_gateway.rb`: 2
- `agricultural_task_active_record_gateway.rb`: 2
- `farm_active_record_gateway.rb`: 2
- `interaction_rule_active_record_gateway.rb`: 2
- `crop_memory_gateway.rb`: 3 (view, edit, masters)

## Phase 別目標


| Phase      | 対象 TODO | 削減目標                                                  |
| ---------- | ------- | ----------------------------------------------------- |
| A 基盤       | t21–t24 | (f) 14→0、Adapter 例外翻訳 36→0、Logger/Translator new 76→0 |
| B Concerns | t33–t35 | concerns AR 80+→0、rescue 6→0                          |
| C ドメイン E2E | t25–t32 | form_with 12→0、Controller AR 100+→0                   |
| D Plan系    | t36–t38 | Plan/PublicPlan controller AR 50→0                    |
| E 残部       | t39–t40 | api/v1 Adapter 直接 new 6→0、Backdoor 除外                 |
| 最終         | t41–t42 | rg 全項目 0、テスト緑                                         |


## 完了基準

- t42 final-audit で (a)–(g) すべて 0 (Backdoor 除外含む)。
- `run-test-rails.sh` 緑、遅延テストしきい値以下。

