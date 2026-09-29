# 05 fail-closed 違反（確度高）: agrr 失敗時の成功形レスポンス 2 件

**状態:** 対応計画（未着手・コード変更なし）。
**根拠の扱い:** 本書の事実は 2026-09-29 時点の `master`（`cdfd21ac6`）のコードを読んで確認したもの（`file:line` 付き）。実行して確認していないものは「未確認」と明記する。

## 1. 概要と重大度

`ARCHITECTURE.md` の "Fail-closed and fallback policy"（69-73 行付近）と `.cursor/rules/fallback.mdc`（原則 1-3、禁止例「Gateway / Adapter で例外を握りつぶし、デフォルト値で『成功っぽく』見せる」）に反して、主経路（agrr）が失敗しても成功形の応答を返している箇所が 2 件ある。

| ID | 場所 | 症状 | 重大度 |
|----|------|------|--------|
| A | `crates/agrr-domain/src/field_cultivation/interactors/field_cultivation_climate_data_interactor.rs` `build_climate_output` | agrr `progress` 失敗でも `success: true` を返す。さらに mapper が別アルゴリズム（手計算 GDD）で積算温度を埋める | 高（誤った農業判断の表示に加え、作業記録の `gdd_at_actual` として永続化され得る） |
| B | `crates/agrr-server/src/entry_schedule.rs` `AgrrCropBuilder::build_from` | 作物要件の取得失敗・未存在時に `{}` のまま agrr 最適化へ進む | 中（最終的には `eligible: false` になる経路が多いが、原因が隠れる。`{}` を agrr が受理した場合の挙動は未確認） |

重大度の根拠: A は「失敗を成功として表示する」うえ、失敗が HTTP 層・フロントのどこにも伝わらない（後述 2.A）。B は既存の `eligible:false` マッピングが働くため誤った適期表示の確率は低いが、fail-closed 規約の原則 2（明示エラーまたは `eligible:false`）を原因付きで満たしていない。

### 依頼文からの訂正（コード再確認の結果）

依頼文は A を「積算 GDD 空の成功形 JSON を返す」と要約していたが、実際はそれより悪い。`unwrap_or_else` が返す `{"progress_records": []}` は mapper の `build_daily_gdd` で「progress_records が空 → `calculate_gdd_manually`」に分岐し（`field_cultivation_climate_data_mapper.rs:187-188`）、**非空の `gdd_data`** が生成される。つまり空ではなく、別算出の値が成功として返る（2.A-3）。

## 2. 現状（確認済み事実）

### 2.A field cultivation climate_data

**A-1 握りつぶし箇所**

- `field_cultivation_climate_data_interactor.rs:296-313` `build_climate_output` は `Result` を返さず、`:308-311` で `climate_progress_gateway.calculate_progress(...)` の `Err` を `.unwrap_or_else(|_| json!({ "progress_records": [] }))` で潰す。エラー内容はログにも出ない（この関数は logger を使っていない）。
- 呼び出し元 `assemble_climate_data`（`:258-275`）と `assemble_climate_data_from_fallback`（`:277-294`）は `build_climate_output` の戻りを常に `Ok(Some(...))` で包む。よって `call`（`:111-220`）の `match assemble_climate_data(...)`（`:200-211`）は progress 失敗を検知できず、`:218` の `self.output_port.present(filtered)` に到達する。

**A-2 gateway 側は失敗を表現できている**

- trait `FieldCultivationClimateProgressGateway::calculate_progress` は `Result<Value, Box<dyn Error + Send + Sync>>`（`crates/agrr-domain/src/field_cultivation/gateways/field_cultivation_climate_progress_gateway.rs:5-11`）。
- 実装 `FieldCultivationClimateAgrrGateway`（`crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:64-73`）は daemon 未起動を `map_agrr_daemon_error`（`crates/agrr-adapters-agrr/src/daemon_unavailable.rs:40-46`）で `DaemonUnavailableError`（Display は `"daemon_unavailable"`）に、それ以外は `AgrrDaemonError` にして返す。テスト済み（`crates/agrr-adapters-agrr/tests/field_cultivation_climate_gateway_test.rs:8-32, 36-60`）。
- ただし成功時も `normalize_progress_result`（`progress_daemon_normalize.rs:12-34`）は、`progress_records` も `daily_progress` も無い未知形の payload を `:33` で `empty_progress_result()` に丸める。`daily_progress: []` も同様に空（`:19-21`、テスト `:90-95`）。すなわち「agrr は成功したが 0 件」と「未知形」も空 `progress_records` として domain に届く。

**A-3 mapper の別アルゴリズム（fallback.mdc 原則 3 違反）**

- `field_cultivation_climate_data_mapper.rs:187-188`: `progress_records.is_empty()` のとき `calculate_gdd_manually(weather_data_records, base_temp)`（`:265-292`）を使う。`(平均気温 - base_temperature).max(0)` の単純累積で、`current_stage` は `Null`（`:288`）。agrr 経路は `stage_name` を `current_stage` に入れる（`:249`）。
- 同 mapper `:66` の `debug_info.using_agrr_progress` は `!progress_records.is_empty()`。この `debug_info` は HTTP 応答に含まれない（`crates/agrr-server/src/field_cultivation_climate.rs:118-128` の `success_json` は `field_cultivation / farm / crop_requirements / weather_data / gdd_data / stages` のみ）。クライアントは agrr 由来か手計算由来か判別できない。
- 手計算と agrr の数値がどれだけ乖離するかは未確認（agrr 側のアルゴリズムを読んでいない）。乖離の有無に関わらず、規約上は「別アルゴリズムで成功表示しない」に該当する。
- 既存テスト（`crates/agrr-domain/test/field_cultivation/mappers_field_cultivation_climate_data_mapper_test.rs`）は agrr 経路のみを検証し、手計算経路のテストは存在しない（`build_output_*` 3 件、`:7 / :49 / :92`）。

**A-4 出力ポート・HTTP・フロント**

- 出力ポート `FieldCultivationClimateDataOutputPort` は `present` / `on_error(Error)` の 2 メソッドのみ（`crates/agrr-domain/src/field_cultivation/ports/field_cultivation_climate_data_output_port.rs:4-7`）。`Error` は `message` だけを持つ（`crates/agrr-domain/src/shared/dtos/error.rs`）。impl は 2 つ: `ClimatePresenter`（`field_cultivation_climate.rs:47-54`）と `CaptureClimatePresenter`（`crates/agrr-server/src/work_record_climate_snapshot.rs:34-40`。`on_error` は空実装 `:39`）。
- 既存の失敗経路: interactor は前提条件不足・作物不在・気象なしを `handle_domain_error` → `on_error`（`:107-109, :171-181, :185-196, :202-208`）で通知する。progress 失敗にはこの経路が使われていない。
- HTTP 層は `on_error` のメッセージ文字列から `status_for_message`（`field_cultivation_climate.rs:102-115`）で状態コードを推定する。domain 側は `PassthroughTranslator`（`crates/agrr-server/src/adapters.rs:39-44`、キー文字列をそのまま返す）を注入している（`field_cultivation_climate.rs:192`）ため、メッセージは `api.errors.*` のキー文字列になる。コード読解上、`"api.errors.no_cultivation_period"` は判定語（`栽培期間` / `cultivation period` / `start_date`）に一致せず 500、`"Forbidden"`（`:104`）も 500 になる（実行未検証）。新しい失敗種別を追加する場合、この文字列推定に頼ると意図した状態コードにならない。
- `interactor.call` が `Err` を返した場合は 500 + `e.to_string()`（`field_cultivation_climate.rs:227-232`）。
- 本エンドポイント（`/api/v1/plans/field_cultivations/{id}/climate_data`, `/api/v1/public_plans/field_cultivations/{id}/climate_data`）は `docs/api/openapi.yaml` に記載がない（`grep` で該当なしを確認）。R4 契約テスト（`crates/agrr-r4-contract/tests/`）にも `climate_data` の参照がない。interactor 自体のテストも存在しない（`interactors/mod.rs` の他 interactor と異なり、`field_cultivation_climate_data_interactor.rs` には `#[cfg(test)]` の `include!` が無い。比較: `field_cultivation_show_interactor.rs:105-108`）。
- フロント: `FieldClimateApiGateway` は `GET .../climate_data` を叩く（`frontend/src/app/adapters/plans/field-climate-api.gateway.ts:12-35`）。型 `FieldCultivationClimateData` に `success: boolean` はあるが手計算由来かを示す項目はない（`frontend/src/app/domain/plans/field-cultivation-climate-data.ts:54-62`）。チャート画面は `control.error` を表示できる（`frontend/src/app/components/plans/plan-field-climate.component.ts:118-119`）が、`LoadFieldClimateUseCase` の error ハンドラは `err.error.error ?? err.error.errors ?? err.message` を読む（`frontend/src/app/usecase/plans/field-climate/load-field-climate.usecase.ts:86-93`）。サーバは `{"success": false, "message": ...}` を返す（`field_cultivation_climate.rs:236-239`）ので `message` は読まれず、Angular の `HttpErrorResponse.message` が表示に回る（読解上。実画面は未確認）。これは 07 の領域。
- 他のフロント利用者 3 件（`preview-work-record-climate.usecase.ts:76`、`preview-work-row-mini-climate.usecase.ts:72`、`load-work-day-list.usecase.ts:75`）は HTTP エラーを空状態・`null` に丸める。

**A-5 手計算 GDD が永続化される経路**

- 作業記録の作成・更新は `WorkRecordClimateSnapshotGateway::lookup` を使い、`gdd_at_actual` と `weather_snapshot` を保存する（`work_record_create_interactor.rs:156-165`、`work_record_update_interactor.rs:79-89`）。実装 `WorkRecordClimateSnapshotService::lookup` は同じ `FieldCultivationClimateDataInteractor` を使う（`work_record_climate_snapshot.rs:121-150`）。
- よって progress 失敗時、手計算の累積 GDD が `work_records.gdd_at_actual` に保存され得る（A-1 と A-3 の合成による読解。実 DB での再現は未確認）。
- 現状の `lookup` は `interactor.call(input)?` の後、`presenter.output` が無ければ `WorkRecordClimateSnapshot::empty()`（`:145-150`）。create/update 側は `lookup` の `Err` を `.ok()` / `if let Ok` で無視する（上記行）。

**A の未確認事項**

- crop に有効な stage が 0 件のとき（`climate_crop_agrr_requirement_from_entity` は温度・熱要件を欠く stage を `continue` で捨てる、`climate_crop_agrr_requirement_mapper.rs:9-16`）、agrr が `Err` を返すか空 progress を返すか。
- 同 interactor 内の `load_plan_prediction_payload(...).unwrap_or(json!({}))`（`:361-362`）は後段の `assert_valid_weather_payload`（`:503-514`）で検証されるため直接の成功偽装ではないが、06 側で扱う（10 章）。

### 2.B entry schedule の作物要件

**B-1 握りつぶし箇所**

- `crates/agrr-server/src/entry_schedule.rs:127-142`。`AgrrCropBuilder::build_from` は `build_crop_agrr_requirement(&self.pool, self.crop_id).ok().flatten().unwrap_or(json!({}))`（`:134-140`）。`build_crop_agrr_requirement`（`crates/agrr-adapters-sqlite/src/crop/agrr_requirement.rs:7-120`）は `Result<Option<Value>, _>` で、DB エラー・crop 行なし（`query_row` の `?`）は `Err`、stage 0 件（`:37-39`）と「温度・熱要件が揃った stage が 0 件」（`:80-82, :99-101`）は `Ok(None)`。`.ok().flatten()` はこの 3 種を区別せず `{}` にする。
- port `CropAgrrRequirementBuilderPort::build_from(&self, &dyn CropAgrrRequirementSource) -> Value`（`crates/agrr-domain/src/shared/ports/crop_agrr_requirement_builder_port.rs:7-9`）は戻り値が `Value` で失敗を表現できない。これが握りつぶしの構造的原因。

**B-2 port の全 impl と呼び出し元（grep で網羅確認）**

| 種別 | 場所 |
|------|------|
| trait 定義 | `crates/agrr-domain/src/shared/ports/crop_agrr_requirement_builder_port.rs:7-9`（re-export `shared/ports/mod.rs:16`） |
| 本番 impl（唯一） | `entry_schedule.rs:132-142` `AgrrCropBuilder`（生成は `:321-324`、`OptimizeRunner::call` 内） |
| テスト impl（唯一） | `crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_optimize_interactor_test.rs:58-68` `StubBuilder` |
| 呼び出し元（唯一） | `crates/agrr-domain/src/cultivation_plan/interactors/entry_schedule_optimize_interactor.rs:82`（`EntryScheduleOptimizeInteractor::call`）。ジェネリクス境界は `:41` |
| 関連マーカー trait | `CropAgrrRequirementSource`（同 port ファイル `:4`）。`EntryScheduleOptimizeCrop` の supertrait（interactor `:20`）、`CropWrap` の空 impl（`entry_schedule.rs:110`）、テストの `TestCrop`（テスト `:20`） |

`OptimizeRunner` の利用元は show / list ハンドラ（`entry_schedule.rs:490-494, :571-575` 付近で `use_agrr_daemon_enabled()` を渡している）。

**B-3 既存の失敗マッピング（整合先）**

- `EntryScheduleOptimizeInteractor::call`（`entry_schedule_optimize_interactor.rs:69-105`）: `agrr_enabled=false` は `failed_result("disabled")`（`:70-72`）、天候不足は `insufficient_weather`（`:74-80`）。`optimize_period` の `Err` は `EntryScheduleOptimizationError` なら `error_key` をそのまま（`:95-99`）、それ以外は `log_error` して `failed_result("crop_requirement_error")`（`:100-103`）にする。
- `failed_result`（`:284-297`）は `eligible: false`、`reason_parts.source = "agrr_failed"`、`reason_parts.error_key` を返す。テスト済み（`maps_non_domain_optimize_errors_to_crop_requirement_error` `:954-999`、`maps_entry_schedule_optimization_error_to_failed_result` `:1003-1032`、`does_not_fall_back_to_temperature_windows_when_optimize_fails` `:311`）。
- つまり `error_key = "crop_requirement_error"` は既に存在し、文言も整備済み: `crates/agrr-server/src/locale_catalog.rs:254`、`config/locales/{ja.yml:83, en.yml:270, in.yml:81}`、`frontend/src/assets/i18n/{ja.json:1697, en.json:722, in.json:1396}`。**B の対応で新規翻訳キーは不要**（`us.yml` に同キーがあるかは未確認）。ja の文言は「作物マスタの情報が不十分です（生育ステージや温度・積算温度要件の欠落）」で、B の原因（stage 0 件・要件欠落）と一致する。
- ただし `agrr_failed` の理由文は `entry_schedule_crop_mapper.rs:200-205` で常に `agrr_failed.generic` になる。個別キー（`agrr_failed.crop_requirement_error` 等）は `reason_parts.error_key` として JSON には出るが、`reason_summary` には反映されない（フロントで `error_key` を使う箇所は grep で見つからず）。個別文言をユーザーに見せるかは今回の必須ではない（8 章）。

**B-4 同一ファイル内の隣接する握りつぶし（B の範囲外だが同型）**

- `entry_schedule.rs:292-299` `load_crop_entity_for_optimize`: `find_by_id` の失敗を `CropEntity::new(crop.id(), crop.name(), None, true)` に置換（`cultivation_method` が `None` になる。テスト `:994-1007` が現状の挙動を固定している）。
- `entry_schedule.rs:167-171` `SqliteOptimizeCropGateway::entry_schedule_ordered_stage_rows`: 温度要件の読取り失敗を `.ok().flatten()` で `None` にする。
- どちらも fail-closed 観点の疑い（未確認: 実害の有無）。06 に引き継ぐ（10 章）。

**B-5 cultivation_plan 側の同型パターン**

- 作物要件の欠落を握りつぶさない実装が既にある: 最適化入力 `cultivation_plan_optimization_sqlite_gateway.rs:81-82`（`build_crop_agrr_requirement(...)?.ok_or_else(|| format!("crop {crop_id} has no growth stages"))?`）、タスクスケジュール生成 `task_schedule_generation_read_gateway.rs:210-216`（`ok_or_else(|| "crop #{crop_id} has no agrr requirement")`）。これらが B の修正方針の先例。
- adjust 側 `plan_allocation_adjust_read_gateway.rs:399-414` は `None` を `requirement: None` として渡す。ただし成長ステージ 0 件は `plan_allocation_adjust_interactor.rs:131-138` で `crop_missing_growth_stages` の明示エラーになる。残る隙間（stage はあるが温度・熱要件が揃わず `Ok(None)` になるケース）は未確認。06 で扱う。
- `cultivation_plan` 内で `unwrap_or(json!({}))` 型の要件握りつぶしは grep で見つからなかった（B のみ）。

## 3. あるべき振る舞い（fail-closed 規約）

### 3.A climate_data

- agrr progress が `Err` の場合: 成功応答を返さない。`gdd_data` を別アルゴリズムで埋めない。`on_error` 系の出力ポート経由で失敗を通知する（LAYER-RULES R5）。
- agrr が成功でも `progress_records` が 0 件の場合: 失敗として扱う案（推奨）。先例: `task_schedule_generate_interactor.rs:224-232`（空 progress は `EMPTY_GDD_PROGRESS` エラー）。
- mapper の `calculate_gdd_manually` と `using_agrr_progress` は削除する（呼ばれなくなるため。`project-necessary-code-only`）。
- HTTP: 状態コード案は下記。body は `{"success": false, "error_key": "climate_progress_unavailable", "message": <翻訳済み or キー>}` を案とする。

| 案 | 状態コード | 理由 |
|----|-----------|------|
| 案1（推奨） | 503 | 一過性の依存先不在。`entry_schedule.rs:220,229,391` の 503 先例と揃う。フロントは 502/503 を backend warmup として扱う（`frontend/src/app/core/backend-warmup/backend-warmup.ts:117`） |
| 案2 | 502 | 上流（agrr）失敗の意味には合うが、同じ warmup 分類 |
| 案3 | 500 | 現状の `interactor.call` の `Err` と同じ。原因種別が伝わらない |

### 3.B entry schedule

- 作物要件が取得できない・未定義の場合、agrr を呼ばず `eligible: false` + `reason_parts.error_key = "crop_requirement_error"` を返す（既存キー・既存文言・既存 `failed_result` を再利用）。HTTP 状態は変えない（`eligible:false` は 200 の本文で表現する既存契約）。
- DB エラー（`Err`）と要件未定義（`Ok(None)`）は port 上で区別する必要はない（どちらも `crop_requirement_error`）。ログで区別する。

### ユーザー確認が必要な点

1. A の HTTP 状態コード（503 / 502 / 500）。
2. A で「agrr 成功だが `progress_records` 0 件」を失敗にしてよいか（正当な 0 件があり得るか、agrr 仕様は未確認）。
3. A の作業記録スナップショットで progress 失敗時の扱い。推奨は `gdd_at_actual = None` で保存を続行（誤値を保存しない）。代替は作業記録の作成・更新自体を失敗にする（利用者影響が大きい）。
4. B の port 形状（5 章の案 B-1 / B-2）。
5. B-4 の隣接 2 箇所を本件に含めるか、06 に送るか。

## 4. 影響範囲

### 4.A climate_data

| 区分 | 対象 |
|------|------|
| domain interactor | `field_cultivation_climate_data_interactor.rs`（`build_climate_output` を `Result` 化、`call` の分岐追加） |
| domain error | `crates/agrr-domain/src/field_cultivation/errors/`（新規 `ClimateProgressUnavailableError`。既存 `WeatherPayloadInvalidError` と同じ置き場） |
| domain port | `FieldCultivationClimateDataOutputPort` に `on_progress_unavailable(Error)` を追加。impl 2 件（`field_cultivation_climate.rs:47`、`work_record_climate_snapshot.rs:34`）の更新が必須 |
| domain mapper | `field_cultivation_climate_data_mapper.rs`（`calculate_gdd_manually` と `using_agrr_progress` の削除、`:187-188` の分岐整理） |
| adapter | 変更不要（gateway は既に `Err` を返す）。`normalize_progress_result:33` の未知形→空は domain 側の「空は失敗」で吸収する案（8 章） |
| HTTP | `field_cultivation_climate.rs`（`ClimateOutcome` に失敗種別、状態コード・body） |
| 呼び出し元 | HTTP ハンドラ（`run_climate_data`）と作業記録スナップショット（`work_record_climate_snapshot.rs`）の 2 件のみ（`FieldCultivationClimateDataInteractor` の grep 結果） |
| テスト | 新規 interactor テスト（現状ゼロ）、mapper テスト、R4 契約 |
| フロント | 表示可能な失敗状態は既存（`plan-field-climate.component.ts:118`）。具体メッセージ表示は 07 依存。i18n を足す場合は `plans-field-climate-keys.spec.ts` の必須キー一覧の更新が必要 |
| 翻訳キー | 新規 `api.errors.climate_progress_unavailable`（`config/locales/{ja,en,in}.yml` と `frontend/src/assets/i18n/{ja,en,in}.json`。`api.errors.no_weather_data` と同じ置き場。`us.yml` の要否は未確認）。フロント個別文言を出す場合のみ `plans.field_climate.*` に追加 |
| ドキュメント | `docs/api/openapi.yaml` に当該 endpoint なし（08 で扱う） |

### 4.B entry schedule

| 区分 | 対象 |
|------|------|
| domain port | `crop_agrr_requirement_builder_port.rs:9` の戻り値を `Result<Value, Box<dyn Error + Send + Sync>>` に変更 |
| domain interactor | `entry_schedule_optimize_interactor.rs:82-83`（`match` で `Err` → `log_error` + `failed_result("crop_requirement_error")`） |
| impl | `entry_schedule.rs:132-142`（唯一の本番 impl。`Ok(None)` を `Err` に変換） |
| テスト impl | `StubBuilder`（`...optimize_interactor_test.rs:58-68`）を `Ok(...)` に更新（既存テストの本文は不変） |
| 呼び出し元 | interactor `:82` の 1 箇所のみ |
| フロント・翻訳 | 変更なし（キー・文言が既存） |
| ドキュメント | `entry_schedule/crops` は `docs/api/openapi.yaml` に記載なし（08） |

## 5. 対応方針（層ごとの変更）

### 5.A climate_data

1. **domain error**: `ClimateProgressUnavailableError`（`message` を持つ。`WeatherPayloadInvalidError` の型に倣う）。
2. **interactor**: `build_climate_output` を `Result<FieldCultivationClimateDataOutput, Box<dyn Error + Send + Sync>>` にする。
   - `calculate_progress` の `Err` → logger.warn（原因文字列を残す）→ `ClimateProgressUnavailableError`。
   - `Ok` でも `progress_records` が空 → 同エラー（3 章の確認 2 が前提）。
   - `assemble_climate_data` / `assemble_climate_data_from_fallback` で `?` 伝播。
   - `call` の `match`（`:200-211`）に `Err(err) if err.downcast_ref::<ClimateProgressUnavailableError>().is_some()` を追加し `self.output_port.on_progress_unavailable(Error::new(self.translator.t("api.errors.climate_progress_unavailable", ...)))` して `return Ok(())`。`RecordNotFoundError` の downcast 分岐（`:127, :164`）と同型で、既存コードとの一貫性を優先する（R5 の "rescue-as-control-flow" に厳密に従うなら enum 戻り値化が代替案。既存 interactor と揃えるため本計画では採らない）。
3. **output port**: `on_progress_unavailable(&mut self, error: Error)` を追加。`on_error` の文字列推定（`status_for_message`）に頼らず状態コードを確定できる。
4. **mapper**: `calculate_gdd_manually` と `using_agrr_progress` を削除。`build_daily_gdd` の空分岐は `daily_gdd = vec![]`（到達しない防御）にせず、空を扱わない構造に整理する。
5. **server**: `ClimatePresenter` に失敗種別を追加し `503`（確認 1 の結果に従う）+ `{"success": false, "error_key": "climate_progress_unavailable", "message": ...}`。`CaptureClimatePresenter::on_progress_unavailable` は空実装（確認 3 の推奨案。誤値を保存しない）。
6. **翻訳**: 3 ロケール分のキー追加。
7. **フロント**: 本件では必須変更なし（既存の失敗状態表示が働く）。原因別メッセージは 07 のエラー契約に従って後続対応。

### 5.B entry schedule

案 B-1（推奨・最小）: port を `Result` にする。

1. port: `fn build_from(&self, crop_source: &dyn CropAgrrRequirementSource) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>`。
2. interactor `:82`: `Err(e)` → `self.log_error(...)` → `return self.failed_result("crop_requirement_error")`。`optimize_period` を呼ばない。
3. impl `AgrrCropBuilder`: `build_crop_agrr_requirement(...)?.ok_or_else(|| format!("crop #{} has no agrr requirement", ...).into())`（`task_schedule_generation_read_gateway.rs:214-215` と同型）。
4. `StubBuilder` を `Ok(...)` に更新。

案 B-2: port と `CropAgrrRequirementSource` を廃止し、interactor が既存の `crop::gateways::CropAgrrRequirementGateway::build_for_crop_id -> Result<Option<Value>, _>`（`crates/agrr-domain/src/crop/gateways/crop_agrr_requirement_gateway.rs:4`、impl `crates/agrr-adapters-sqlite/src/crop/crop_agrr_requirement_gateway.rs:16-23`）を直接使う。`AgrrCropBuilder`（server private）が不要になり、`None` を型で表現できる。波及は `EntryScheduleOptimizeCrop` の supertrait 削除（`:20`）、`CropWrap` / `TestCrop` の空 impl 削除、interactor のジェネリクス変更（`B` → 既存 gateway 型）、`EntryScheduleOptimizeInteractor::new` の全呼び出し（`entry_schedule.rs:325-334` とテスト 22 箇所、`interactors_entry_schedule_optimize_interactor_test.rs` の `EntryScheduleOptimizeInteractor::new(` 呼び出し）で大きい。設計上は綺麗だが、ユーザー依頼（port を `Result` にする波及の提示）の範囲を超えるため、採否はユーザー確認とする。

B-4 の隣接 2 箇所は確認 5 の結果に従う（本件に含める場合は `load_crop_entity_for_optimize` が `Result` を返す形にし、失敗時は同じく `crop_requirement_error` 系の `failed_result` に流す。テスト `:994-1007` は期待値を更新する）。

## 6. TDD 計画（RED の失敗テスト）

実行は `test-common` のスクリプトのみ。出力は `./tmp/{UUID}.log` にリダイレクトして grep する（`AGENTS.md`）。RED を確認してから GREEN に進む（`tdd-on-edit`）。

注意: `agrr-server` の inline テスト（`entry_schedule.rs` 末尾、`field_cultivation_climate.rs` 等）は `run-test-rust-domain.sh`（`cargo test -p agrr-domain` と `agrr-migrate`）にも CI（`.github/workflows/rust-domain-test.yml:51-58`。`agrr-domain` / `agrr-migrate` / `agrr-adapters-sqlite -- '_gateway_test'`）にも含まれない。ゲートされないテストは RED/GREEN の根拠にしない。server 層の振る舞いは R4 契約で固定する。

### 6.A climate_data

| # | 種別 | パス案 | given / when / then | 現状の期待 | スクリプト |
|---|------|--------|--------------------|-----------|-----------|
| A-R1 | domain | 新規 `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_climate_data_interactor_test.rs`（interactor 末尾に `#[cfg(test)] mod ... { include!(...) }` を追加。`field_cultivation_show_interactor.rs:105-108` に倣う） | given: 権限・source・crop・気象 payload が正常で、progress gateway が `Err("daemon_unavailable")` を返す。when: `call`。then: `on_progress_unavailable` が 1 回、`present` は 0 回、`call` は `Ok(())` | 現状は `present` が呼ばれ RED（`on_progress_unavailable` 未定義のため先にコンパイルエラー。コンパイルエラーの RED は Rust の新規 API 追加では正当） | `run-test-rust-domain.sh field_cultivation_climate_data_interactor` |
| A-R2 | domain | 同上 | given: progress gateway が `Ok({"progress_records": []})`。then: A-R1 と同じ | 現状は手計算 GDD を `present` して RED | 同上 |
| A-R3 | domain | 同上 | given: progress gateway が正常な `progress_records`。then: `present` の `gdd_data` が agrr の値（stage 名付き）で、`on_progress_unavailable` は 0 回 | 現状も GREEN（特性化テスト。退行防止） | 同上 |
| A-R4 | domain | 既存 `mappers_field_cultivation_climate_data_mapper_test.rs` に追加 | given: `progress_result = {"progress_records": []}` と非空の weather。when: `build_output`。then: `gdd_data` が空で、手計算値が入らない | 現状は非空で RED | `run-test-rust-domain.sh field_cultivation_climate_data_mapper` |
| A-R5 | domain | A-R1 と同ファイル | given: progress gateway が `Err`。then: logger.warn に原因文字列が出力される（Fake logger で捕捉） | 現状は未出力で RED | 同上 |
| A-R6 | R4 契約 | `crates/agrr-r4-contract/tests/contracts.rs`（`support.rs` に climate 用 seed が必要な可能性。`field_cultivations` の seed は `support.rs:457, 933, 1192` に既存だが、キャッシュ済み予測気象まで揃うかは未確認） | given: agrr daemon が到達不能（binary 不在の環境）で climate_data を取得。then: 503 と `success:false`、`error_key = "climate_progress_unavailable"`。binary 有りの環境では daemon 停止を作れないためスキップ（`agrr_regeneration_contract_available()` 分岐の先例、`contracts.rs` の entry_schedule 契約 `:4766-4810`） | 現状は 200 で RED（daemon 不在環境のみ。決定的な RED を作れるかは未確認。確認手順: binary 無しで `run-rust-contract-tests.sh` を実行して観測） | `scripts/run-rust-contract-tests.sh` |
| A-R7 | adapter（任意） | `crates/agrr-adapters-agrr/src/progress_daemon_normalize.rs` inline | 未知形 payload の扱いを `Err` にする場合のみ（8 章の判断待ち） | — | `cargo test -p agrr-adapters-agrr` は test-common に無いため、採用時は実行経路をユーザーと決める |

作業記録スナップショットの回帰（確認 3 が推奨案の場合）: 既存の `interactors_work_record_create_interactor_test.rs` / `...update...` は `WorkRecordClimateSnapshot::empty()` の gateway スタブ（`:175`, `:141`）で、`lookup` の実 interactor を通らない。`CaptureClimatePresenter` の挙動は server inline テストになるためゲートされない。R4 で「progress 不可でも作業記録が作成でき `gdd_at_actual` が null」を確認する契約を追加するか、ユーザーに判断を仰ぐ（未確認: 既存 R4 の作業記録 seed で daemon 不在を再現できるか）。

### 6.B entry schedule

| # | 種別 | パス案 | given / when / then | 現状の期待 | スクリプト |
|---|------|--------|--------------------|-----------|-----------|
| B-R1 | domain | `crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_optimize_interactor_test.rs`（`:954` 付近、`maps_non_domain_optimize_errors_to_crop_requirement_error` の隣） | given: builder が `Err("no requirement")`（新シグネチャ）。when: `call`。then: `eligible == false`、`error_key == "crop_requirement_error"`、`StubOptimizationGateway.captured_requirement` が `None`（`optimize_period` 未呼び出し） | 現状はシグネチャ不一致のコンパイルエラーで RED。あわせて「現行のまま builder が `{}` を返しても `optimize_period` が呼ばれる」ことを `captured_requirement == Some({})` で先に観測しておくと、握りつぶしの証拠になる | `run-test-rust-domain.sh entry_schedule_optimize` |
| B-R2 | domain | 同上 | given: builder `Ok(要件)`。then: 既存 `scales_crop_requirement_before_optimize_period`（`:241`）が GREEN のまま | 特性化（退行防止） | 同上 |
| B-R3 | domain | 同上 | given: builder `Err`。then: logger.error が 1 回（Fake logger 捕捉） | 現状は未出力で RED | 同上 |
| B-R4 | R4 契約 | `contracts.rs`（`get_entry_schedule_crop_show_*` の隣）+ `support.rs` の `seed_entry_schedule_contract_assets`（`:758` 付近）に「stage はあるが `thermal_requirements` 行なし」の作物を作る seed を追加 | given: 参照農場・参照作物（要件欠落）・agrr 有効（`run-rust-contract-tests.sh:278-281` は binary があるときのみ `USE_AGRR_DAEMON=true`）。when: `GET /api/v1/public_plans/entry_schedule/crops/{id}?farm_id=`。then: 200、`crop.eligible == false`、`crop.reason_parts.error_key == "crop_requirement_error"` | 現状の観測値は未確認（agrr が `{}` を拒否すれば `execution_failed`、受理すれば別結果）。RED 実行で観測する。binary 不在環境では `disabled` になるためスキップ | `scripts/run-rust-contract-tests.sh` |

## 7. 実装ステップ

A と B は独立した変更セットにできる（ファイル・型が重ならない）。それぞれ `RED → GREEN → REFACTOR`（`tdd-on-edit`）。テストだけの赤いコミットは CI を壊すため、RED は作業ツリーで確認し、コミットは GREEN 到達単位でまとめる。

**A（この順）**

1. 確認 1-3 の回答を得る（3 章）。
2. A-R1〜R5 を書き、`run-test-rust-domain.sh` で RED を確認。
3. domain: error 型、output port メソッド、interactor、mapper の最小変更で GREEN。両 impl のスタブ更新。→ コミット 1「domain: climate progress 失敗を fail-closed にする」。
4. server: `ClimatePresenter` / `CaptureClimatePresenter`、状態コード、翻訳キー（yml + json）。A-R6 を追加して `run-rust-contract-tests.sh`。→ コミット 2。
5. REFACTOR: 手計算の残骸（`calculate_gdd_manually`、`using_agrr_progress`）が残っていないことを確認。
6. フロントの原因別メッセージは 07 の後続（本件では変更しない）。変更する場合は `run-test-frontend.sh`。
7. Docker 検証: `crates/agrr-server/**`・`crates/agrr-domain/**` を変更したので、検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必要（`docker compose restart agrr-server` では不十分）。
8. 完了後 `test-slow-detection`。個別 GREEN → 全体（`run-test-rust-domain.sh` 引数なし + `run-rust-contract-tests.sh`）の順。

**B（この順）**

1. 確認 4-5 の回答を得る。
2. B-R1・B-R3 を追加（B-R1 の前に、現行で `{}` が `optimize_period` に渡ることを観測するテストを一時的に書いて記録する）。RED 確認。
3. port・interactor・`AgrrCropBuilder`・`StubBuilder` を変更して GREEN。→ コミット 1。
4. B-R4（seed 追加を含む）を追加して `run-rust-contract-tests.sh`。→ コミット 2。
5. `crates/agrr-server/**` と `crates/agrr-domain/**` を変更するため、Docker 検証前に `rebuild-restart.sh`。
6. B-4 を含める場合は別コミット（`load_crop_entity_for_optimize` と `entry_schedule_ordered_stage_rows`）。

## 8. リスク・未確定事項

| # | 内容 | 状態 |
|---|------|------|
| 1 | agrr が `progress_records` 0 件を正常に返す正当なケースがあるか | 未確認。3 章確認 2 |
| 2 | `normalize_progress_result:33` が未知形を空に丸める点。domain の「空は失敗」で吸収できるが、原因が「未知形」か「0 件」かはログで区別できない。adapter を `Err` にするなら `progress_daemon_normalize.rs` のテスト更新と、`task_schedule_progress_gateway.rs`（同 gateway を共用、`:59-61`）への影響確認が必要 | 未確定 |
| 3 | 作業記録の `gdd_at_actual` が null になる頻度が、agrr 障害時に増える（誤値保存の代わり）。利用者に見えるのは空表示 | 確認 3 |
| 4 | 既に永続化済みの手計算由来 `gdd_at_actual` を識別・是正する手段がない（`work_records` に由来フラグなし）。是正が必要かは本番データの観測が要る | 未確認（`production-primary-sqlite-query` スキルで調査可能） |
| 5 | フロントの 3 利用者はエラーを空状態に丸めるため、503 化後は「空表示」になる（現状は手計算のグラフが出る）。利用者に見える退行に見えるが、規約上は正しい | 受容の確認が必要 |
| 6 | `agrr-server` inline テストが CI ゲート外。server 層の状態コード・presenter は R4 でしか固定できず、R4 は agrr binary の有無で分岐するため決定的な RED を作れない可能性 | 未確認（A-R6・B-R4） |
| 7 | 案 B-2 の波及の大きさ（5.B） | ユーザー判断 |
| 8 | B の RED が現状でどう振る舞うか（agrr が `{}` を受理するか） | 未確認。RED 実行で観測 |
| 9 | `status_for_message` が文字列推定である点（`"Forbidden"` が 500 になる読解）。A の新規種別は専用ポートメソッドで回避するが、既存分岐は別課題 | 10 章の 07 / 10 |

## 9. 受け入れ条件

**A**

- [ ] `calculate_progress` が `Err` のとき、`climate_data` API は `success:true` を返さず、確定した状態コード（推奨 503）と `error_key = "climate_progress_unavailable"` を返す。
- [ ] `progress_records` が 0 件のとき（確認 2 の結果が「失敗」の場合）同様に失敗する。
- [ ] `calculate_gdd_manually` と `using_agrr_progress` がコードベースから消えている（`grep` で 0 件）。
- [ ] `FieldCultivationClimateDataInteractor` の interactor テストが存在し、A-R1〜R5 が GREEN。
- [ ] `run-test-rust-domain.sh`（全体）と `run-rust-contract-tests.sh` が GREEN。遅延検知（`test-slow-detection`）を実施済み。
- [ ] 作業記録の作成・更新は progress 失敗時に手計算値を保存しない（確認 3 の結果に従う）。
- [ ] 新規翻訳キーが 3 ロケールに揃っている。

**B**

- [ ] 作物要件が取得できない・未定義のとき、`optimize_period` が呼ばれず `eligible:false` + `error_key = "crop_requirement_error"` になる（B-R1 GREEN）。
- [ ] `AgrrCropBuilder` に `.ok().flatten().unwrap_or(json!({}))` が残っていない。
- [ ] 既存テスト（`does_not_fall_back_to_temperature_windows_when_optimize_fails` ほか）が GREEN のまま。
- [ ] `run-test-rust-domain.sh` と `run-rust-contract-tests.sh` が GREEN。
- [ ] Docker で確認する場合は `rebuild-restart.sh` 後に実施している。

## 10. 関連課題との依存

| 番号 | 関係 |
|------|------|
| 06 fail-closed-suspected | 同型の疑い箇所を引き継ぐ: `field_cultivation_climate_data_interactor.rs:361-362`（`unwrap_or(json!({}))`）、`entry_schedule.rs:167-171, :292-299`（B-4）、`plan_allocation_adjust_read_gateway.rs:399-414`（要件 `None`）、`field_cultivation_climate.rs:89-92` と `work_record_climate_snapshot.rs:64-78`（`StoreBackedWeatherPredictionService` が store の `Err` を `.ok().flatten()` で潰す）、`work_record_create_interactor.rs:158-164` / `work_record_update_interactor.rs:82-84`（`lookup` の `Err` 無視）、`adjust_weather_prediction.rs:118, :142`（`.ok().flatten()`）、`crates/agrr-domain/src/shared/ports/interaction_rule_agrr_format_builder_port.rs:9`（`build_from -> Value` の同形 port。失敗表現なし。実害は未確認）。本書では扱わない。 |
| 07 frontend-error-contract | `load-field-climate.usecase.ts:86-93` が `message` を読まない点、3 利用者がエラーを空状態に丸める点、`error_key` の受け方。A の原因別メッセージ表示は 07 の契約決定後。 |
| 08 openapi-gaps | `climate_data` と `entry_schedule/crops` が `docs/api/openapi.yaml` に無い。A の 503 / `error_key` 応答は 08 で記載する。 |
| 10 authorization-consistency | `climate_data` の `Forbidden` が `status_for_message` で 500 になる読解（実行未検証）。認可エラーの状態コード統一として 10 で扱う。A の変更では触れない。 |
| 01 resource-limit-bypass / 02 contact-recaptcha / 03 api-key-scope-docs / 04 api-key-query-auth | 依存なし（対象コードが重ならない）。 |
| 09 stale-design-docs | `docs/migration/archive/` と `.cursor/skills/cultivation-climate-chart-investigation/references/code-paths.md`（`FieldCultivationClimateDataMapper.build_daily_gdd` の記述が手計算分岐に触れていない）を、A 完了後に更新する候補。 |
| 11 low-priority-misc | 依存なし。 |
