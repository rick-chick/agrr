# app/services 残存 8 本の処遇（T-037）

ロードマップ T-037 に基づき、以下を **確定分類** とする。後続の実装タスク（T-038 以降）は別 PR で本表を参照する。

| サービス | 分類 | 移行先 / 方針 | 推定リスク | 備考 |
|---------|------|----------------|------------|------|
| `agrr_service.rb` | **B Gateway** | `lib/adapters/agrr/` または既存 `app/gateways/agrr/` を `Domain::*::Gateways` インターフェース経由に正規化 | 中 | デーモン起動・CLI の単一入口。例外型の整理と T-015 基底統合と連動 |
| `crop_ai_upsert_service.rb` | **A Interactor** | `lib/domain/crop/interactors/`（または該当ドメイン）＋契約 `crop-contract.md` 追記 | 中 | 外部 AI / マスタ更新の境界を Gateway に分離 |
| `crop_task_schedule_blueprint_create_service.rb` | **A Interactor** | `lib/domain/agricultural_task/interactors/` または `crop` 配下 | 中 | T-033 タスク生成系と責務が隣接 |
| `crop_task_schedule_blueprint_generator.rb` | **A Interactor** | 同上（生成専用）。Create と統合可否は実装時に判断 | 低〜中 | 純粋生成ならドメインサービス化も可 |
| `crops/task_schedule_blueprint_deletion_service.rb` | **A Interactor** | `lib/domain/crop/interactors/` | 低 | 削除フローは Presenter + Interactor に寄せる |
| `fields_allocator.rb` | **A Interactor** | `lib/domain/cultivation_plan/interactors/`（配置はドメインルール） | 高 | agrr 連携あり。Gateway（optimization / allocation）と整合 |
| `pest_crop_association_service.rb` | **A Interactor** | `lib/domain/pest/interactors/` または `crop` ドメイン | 中 | マスタ関連付け。API コントローラから直接呼ばない |
| `plan_copier.rb` | **A Interactor** | `lib/domain/cultivation_plan/interactors/` | 中 | `PlanSaveSession` と重複・再利用箇所を整理 |

**分類凡例**: A = Interactor 昇格、B = Gateway、C = Orchestrator（本 8 本では C は採用しない）。
