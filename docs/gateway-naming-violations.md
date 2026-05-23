# Gateway ネーミング規約違反の洗い出し

## 判定基準 (ARCHITECTURE.md より)

### ファイル命名規約
- **アダプター接尾辞**: 7つのみ許可 (`_active_record_gateway`, `_http_gateway`, `_cli_gateway`, `_daemon_gateway`, `_memory_gateway`, `_action_cable_gateway`, `_active_job_gateway`)
- **禁止接尾辞**: `_gateway_adapter`, `_active_gateway`, `_through_host_gateway`, 接尾辞なし
- **禁止中接辞**: `*_rest_*_gateway`, `*_html_*_gateway`, `*_json_*_gateway` (プレゼンテーションチャネル名)
- GCS/S3 は `_http_gateway`

### メソッド命名規約 (5つの動詞)
- `find_by_*(criteria)` → Entity | nil
- `list_by_*(criteria)` → Array<Entity>
- `create(...)` → 永続化済みEntity
- `update(...)` → 永続化済みEntity
- `delete(id)` → 結果
- **許可例外**: `get_<state>` (スカラーのみ), `fetch_*` (外部I/Oのみ), `upsert_*`, `soft_delete_with_undo`
- **禁止**: `get_<entity>`, `load_<entity>`, `find_<entity>_by_*`, `list_<entity>_by_*`, `query_*`, `by_*`, `save`, `destroy`

### ゲートウェイ境界
- ゲートウェイは狭い永続化/HTTP/プロセスI/Oのみ
- 認可・バリデーション・マルチエンティティオーケストレーションは禁止
- プレゼンター形状の複合DTOのアセンブリは禁止

---

## A. ファイル命名違反 (10件)

### A-1. `app/adapters/public_plan/gateways/entry_schedule_cursor_decode_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `EntryScheduleCursorDecodeGateway` |
| 違反 | アダプター接尾辞なし。Base64/JSONデコードは純計算でI/Oではない |
| 判定 | **ゲートウェイとして不適格**。ユーティリティクラスへ移動すべき |
| 修正 | ゲートウェイから除外。`app/adapters/public_plan/entry_schedule_cursor_decoder.rb` / `EntryScheduleCursorDecoder` |

### A-2. `app/adapters/backdoor/gateways/shell_stdout_capture_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `ShellStdoutCaptureGateway` |
| 違反 | アダプター接尾辞なし。シェルコマンド実行はプロセスI/O → `_cli_gateway` |
| 修正 | `shell_stdout_capture_cli_gateway.rb` / `ShellStdoutCaptureCliGateway` |

### A-3. `app/adapters/field_cultivation/gateways/field_cultivation_climate_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `FieldCultivationClimateGateway` |
| 違反 | `_climate_gateway`は許可接尾辞外。また`Domain::FieldCultivation::Gateways::FieldCultivationGateway`を継承しているが、認可チェック・マルチゲートウェイオーケストレーション・複合DTOアセンブリを行う巨大なクラス |
| 判定 | **ゲートウェイ境界違反**。インタラクターとして再設計すべき |
| 修正 | 削除。機能はインタラクターに分割。ゲートウェイは`field_cultivation_active_record_gateway.rb`に統合 |

### A-4. `app/adapters/weather_data/gateways/agrr_prediction_gateway_adapter.rb`
| 項目 | 値 |
|---|---|
| クラス | `AgrrPredictionGatewayAdapter` |
| 違反 | `_gateway_adapter`は禁止接尾辞。`PredictionDaemonGateway`への薄いラッパー |
| 判定 | **不要なラッパー**。呼び出し側で`PredictionDaemonGateway`を直接参照すべき |
| 修正 | 削除。呼び出し側を`PredictionDaemonGateway`へ変更 |

### A-5. `app/adapters/shared/gateways/masters_api_session_resolve_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `MastersApiSessionResolveGateway` |
| 違反 | アダプター接尾辞なし。マルチゲートウェイ合成を行う（`SessionCookieUserActiveRecordGateway` + AR直接参照） |
| 判定 | **ゲートウェイ境界違反**。インタラクターとして再設計すべき |
| 修正 | ゲートウェイから除外。インタラクターとして再設計 |

### A-6. `app/adapters/shared/gateways/sql_like_active_record_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `SqlLikeActiveRecordGateway` |
| 違反 | `Domain::Shared::Ports::SqlLikeSanitizePort`を実装している→インフラストラクチャポート。ゲートウェイではない |
| 判定 | **ポート/ゲートウェイの区別違反**。ポートアダプターとして再配置 |
| 修正 | `app/adapters/shared/ports/sql_like_active_record_adapter.rb` / `SqlLikeActiveRecordAdapter` |

### A-7. `app/adapters/cultivation_plan/gateways/plan_copy_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `PlanCopyGateway` |
| 違反 | アダプター接尾辞なし。ActiveRecordを使用 |
| 判定 | **ゲートウェイ境界違反**（マルチエンティティオーケストレーション）。インタラクターとして再設計すべき |
| 修正（命名のみ） | `plan_copy_active_record_gateway.rb` / `PlanCopyActiveRecordGateway`（再設計は別タスク） |

### A-8. `app/adapters/cultivation_plan/gateways/crop_task_schedule_blueprint_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `CropTaskScheduleBlueprintGateway` |
| 違反 | アダプター接尾辞なし。ActiveRecordを使用 |
| 判定 | **ゲートウェイ境界違反**（マルチエンティティオーケストレーション）。インタラクターとして再設計すべき |
| 修正（命名のみ） | `crop_task_schedule_blueprint_active_record_gateway.rb` / `CropTaskScheduleBlueprintActiveRecordGateway`（再設計は別タスク） |

### A-9, A-10. `plan_data_available_crop_rows_private/public_active_record_gateway.rb`
| 項目 | 値 |
|---|---|
| クラス | `PlanDataAvailableCropRowsPrivateActiveRecordGateway` / `PlanDataAvailableCropRowsPublicActiveRecordGateway` |
| 違反 | `private`/`public`中接辞は禁止（プレゼンテーションチャネル名）。またインターフェースは`Array<Hash>`を返す→エンティティ/DTOを返すべき |
| 修正 | `crop_rows_available_private_active_record_gateway.rb` / `CropRowsAvailablePrivateActiveRecordGateway`<br>`crop_rows_available_public_active_record_gateway.rb` / `CropRowsAvailablePublicActiveRecordGateway` |

---

## B. メソッド命名違反 (32件)

### B-1. `find_<entity>_by_*` 違反 (メソッド名にエンティティ名を含む)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-1.1 | `lib/domain/pest/gateways/pest_gateway.rb` | `find_user_owned_non_reference_pest_by_name` | `find_by_name` |
| B-1.2 | `lib/domain/fertilize/gateways/fertilize_gateway.rb` | `find_user_owned_non_reference_fertilize_record_by_name` | `find_by_name` |
| B-1.3 | `lib/domain/file_blob/gateways/file_blob_gateway.rb` | `find_row_by_id` | `find_by_id` |
| B-1.4 | `lib/domain/field_cultivation/gateways/field_cultivation_gateway.rb` | `find_climate_data_by_field_cultivation` | `find_climate_data` |
| B-1.5 | `lib/domain/field_cultivation/gateways/field_cultivation_gateway.rb` | `find_api_summary_by_field_cultivation` | `find_api_summary` |
| B-1.6 | `lib/domain/crop/gateways/crop_gateway.rb` | `list_crop_stages_by_crop_id` | `list_by_crop_id` |
| B-1.7 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_crop_stage_by_id` | `find_by_id` |
| B-1.8 | `lib/domain/weather_data/gateways/weather_data_gateway.rb` | `find_weather_location_by_coordinates` | `find_by_coordinates` |
| B-1.9 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | `find_plan_crop_id_by_crop_id!` | `find_crop_id!` |

### B-2. `destroy` → `delete` 違反

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-2.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_temperature_requirement` | `delete_temperature_requirement` |
| B-2.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_thermal_requirement` | `delete_thermal_requirement` |
| B-2.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_sunshine_requirement` | `delete_sunshine_requirement` |
| B-2.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_nutrient_requirement` | `delete_nutrient_requirement` |
| B-2.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_masters_crop_task_template_for_api!` | `delete_masters_crop_task_template_for_api!` |
| B-2.6 | `lib/domain/farm/gateways/farm_gateway.rb` | `destroy` | `delete` |
| B-2.7 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | `destroy` | `delete` |

### B-3. `find_<entity>` 違反 (get_の例外条件に合致しないエンティティ取得)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-3.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_temperature_requirement` | `find_temperature_requirement_by_crop_stage_id` |
| B-3.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_thermal_requirement` | `find_thermal_requirement_by_crop_stage_id` |
| B-3.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_sunshine_requirement` | `find_sunshine_requirement_by_crop_stage_id` |
| B-3.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_nutrient_requirement` | `find_nutrient_requirement_by_crop_stage_id` |
| B-3.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_model` | `find_by_id` |

### B-4. `create_<entity>` / `update_<entity>` 違反 (エンティティ名をメソッド名に含む)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-4.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_crop_stage` | `create` |
| B-4.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_crop_stage` | `update` |
| B-4.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `delete_crop_stage` | `delete` |
| B-4.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_temperature_requirement` | `create` |
| B-4.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_temperature_requirement` | `update` |
| B-4.6 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_thermal_requirement` | `create` |
| B-4.7 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_thermal_requirement` | `update` |
| B-4.8 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_sunshine_requirement` | `create` |
| B-4.9 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_sunshine_requirement` | `update` |
| B-4.10 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_nutrient_requirement` | `create` |
| B-4.11 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_nutrient_requirement` | `update` |

**注意**: B-4の違反は`CropGateway`がサブエンティティ（CropStage, TemperatureRequirement等）のCRUDを包含していること自体が**ゲートウェイ境界違反**（1つのゲートウェイが複数のドメインエンティティを扱う）。修正は別タスクでゲートウェイを分割する。

---

## C. ゲートウェイ境界違反 (6件)

| # | ファイル | 違反内容 | 修正方針 |
|---|---|---|---|
| C-1 | `lib/domain/crop/gateways/crop_gateway.rb` | 認可チェック(`find_authorized_*`)、HTMLフォーム準備(`prepare_*_for_edit_form!`)、マルチエンティティ関連付け(`link_pest_to_crop`等)、プレゼンター形状複合(`find_*_loaded_bundle!`) | インタラクターに分割。ゲートウェイは純粋な永続化I/Oのみ |
| C-2 | `lib/domain/farm/gateways/farm_gateway.rb` | 認可チェック(`find_authorized_*`)、プレゼンター形状複合(`find_authorized_farm_loaded_bundle!`, `farm_list_rows_bundle`) | インタラクターに分割 |
| C-3 | `lib/domain/pest/gateways/pest_gateway.rb` | 認可チェック、HTMLフォーム準備、マルチエンティティ関連付け | インタラクターに分割 |
| C-4 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | 認可チェック、プレゼンター形状複合(`find_*_bundle!`, `*_snapshot`)、マルチエンティティ操作 | インタラクターに分割 |
| C-5 | `app/adapters/field_cultivation/gateways/field_cultivation_climate_gateway.rb` | 認可チェック(`authorized_field_cultivation`)、マルチゲートウェイオーケストレーション、複合DTOアセンブリ | インタラクターとして再設計 |
| C-6 | `app/adapters/shared/gateways/masters_api_session_resolve_gateway.rb` | マルチゲートウェイ合成 | インタラクターとして再設計 |

---

## 対応優先度

| 優先度 | カテゴリ | 件数 | 内容 |
|---|---|---|---|
| **P1** | ファイル命名違反 | 10 | 接尾辞なし/禁止接尾辞/禁止中接辞/誤配置 |
| **P2** | メソッド命名違反 | 32 | `find_<entity>_by_*`, `destroy`, `create_<entity>` |
| **P3** | ゲートウェイ境界違反 | 6 | 認可・フォーム準備・マルチエンティティ・プレゼンター形状複合 |

**P1（ファイル命名）**はリネーム+参照更新で対応可能。
**P2（メソッド命名）**はインターフェース+全アダプター+全インタラクターの更新が必要。
**P3（境界違反）**はアーキテクチャ再設計が必要（別エピック）。
