# 06. fail-closed 違反の疑い（8 項目）: 判定と対応計画

**種別:** 仕様不具合の対応計画（ドキュメント）。本書はコードを変更しない。
**対象:** `crates/agrr-server/src/entry_schedule.rs`、`crates/agrr-domain/src/field_cultivation/interactors/field_cultivation_climate_data_interactor.rs`、`crates/agrr-server/src/optimization_chain_phase.rs`、`crates/agrr-domain/src/cultivation_plan/{calculators/fields_allocation.rs, interactors/cultivation_plan_initialize_interactor.rs, interactors/entry_schedule/window_service.rs}`、`crates/agrr-server/src/weather_reschedule_proposals.rs`。

根拠は 2026-09-29 時点で実際に読んだファイル・実行した `rg` / `ls` / `grep` のみ。読んでいない・実行していないものは「未確認」と明記する。テストは実行していない（本書は調査と計画のみ）。

---

## 1. 概要

### 1.1 目的と規範

`unwrap_or*` / `.ok()` で失敗を握りつぶし、代替値で成功に見せる箇所 8 件について、規約違反かどうかを確定し、対応方針・TDD 計画・実装順序を定める。

適用する規範（すべて全文を読んだ）:

- `ARCHITECTURE.md:69-73` と `:106-111`: ドメイン判定・ビジネスロジックは、主経路失敗時に別アルゴリズムで「もっともらしい成功」を出してはならない。許容される結果は `eligible: false`、明示エラー、`501` 型の fail-closed のみ。
- `.cursor/rules/fallback.mdc:16-23`（原則）、`:25-29`（許容パターン）、`:31-35`（禁止例）。禁止例に「最適化 API 失敗時に温度ウィンドウ走査へ切り替えて `eligible: true` を返す」（`:33`）と「Gateway / Adapter で例外を握りつぶし、デフォルト値で成功っぽく見せる」（`:34`）がある。
- `.cursor/rules/no-convenience-tech-debt.mdc`: 規約違反は残置しない。「小さいから後回し」は根拠にならない。ドキュメントやコメントの一言追記だけでは解消済みとして扱わない。
- `docs/architecture/LAYER-RULES.md`: R0（Policy が検証を持つ）、R5（結果は output port の `on_success` / `on_failure`。rescue-as-control-flow 禁止）、R7（HTTP エッジは薄く）。
- `.cursor/rules/evidence-before-design-and-implementation.mdc`: 確実性か再現性のどちらかを満たすまで設計・実装しない。
- `.cursor/rules/project-necessary-code-only.mdc`: 依頼・規約・再現済み不具合に結びつかない成果物は書かない。
- `.cursor/skills/tdd-on-edit/SKILL.md` と `.cursor/skills/test-common/SKILL.md`: 実装前に RED を作り `test-common` のスクリプトで確認する。

### 1.2 判定の定義

| 判定 | 意味 |
| ---- | ---- |
| 違反確定 | コード構造が上記規範の文言に該当することを file:line で確認した。本番経路への到達性は別列で示す。到達不能でも規約違反であり残置しない（`no-convenience-tech-debt.mdc`）。 |
| 仕様上許容 | 規範が許す挙動（業務上意味のある「無い」の扱い、遅延計算など）であることをコードで確認した。 |
| 要判断 | 事実だけでは決まらない。プロダクト判断が要る。§3 に確認事項を書く。 |

### 1.3 結果の要約

- 8 項目のうち、**本番経路から到達できるのは項目 1・3・4 のみ**。項目 2 は到達するが結果に影響しない（読んだ値を使う本番コードが無い）。項目 5・6・7・8 は本番の呼び出し元を全数確認した範囲で到達しない。
- **項目 3 は依頼文の前提と実態が違う。** 「主経路がキャッシュ済み予測」ではなく、本番配線では「主経路」に当たる `predict_for_cultivation_plan` が常に `None` を返すスタブで、フォールバック側が唯一の実計算経路になっている（§3.3）。さらに、フォールバック側は正規の予測生成（`WeatherPredictionInteractor`）と同じモデル（`lightgbm`）を使うが、検証の大半を欠く。永続化ステップは、ペイロード形状の不一致により常に失敗する疑いがある（コード読解のみ・未実行のため未確認）。
- **項目 7 は `fallback.mdc:33` の禁止例そのもの**（温度しきい値走査で `eligible: true`）だが、`WindowService` の呼び出し元はテストのみ（`rg` で確認）。
- 項目 4 は「optimizing でない」分岐は許容、「DB エラー・読取失敗」分岐のみ違反確定。
- 依頼範囲外だが同一箇所で見つけた同種の握りつぶしを §2.2 に列挙した（A〜G）。本計画の実装スコープには含めず、同時に直すかを §3 末尾で確認する。

---

## 2. 項目別の判定表

### 2.1 依頼された 8 項目

| # | 項目 | 判定 | 根拠 file:line | 本番経路到達性 | 重大度 |
| - | ---- | ---- | -------------- | -------------- | ------ |
| 1 | `load_crop_entity_for_optimize` が `find_by_id` の Err で `is_reference: true` の代替 Crop を生成 | 違反確定 | `crates/agrr-server/src/entry_schedule.rs:291-299`（`unwrap_or_else` は `:298`）。既存テストがこの代替を表明: `entry_schedule.rs:993-1007` | 到達する。`GET /api/v1/public_plans/entry_schedule/crops/{id}`（`:476-514`）と `.../crops`（`:590-599`）が `OptimizeRunner::call`（`:314-315`）経由で呼ぶ。発火条件は DB 読取エラー（頻度は低い） | 中 |
| 2 | 温度要件取得失敗を `.ok().flatten()` で握りつぶす | 違反確定（現状は実害なし） | `entry_schedule.rs:167-171`。Err を `None` に潰す（`fallback.mdc:34`） | 関数自体は到達する（`entry_schedule.rs:160-181` は最適化経路の `crop_gw`、`:318-320`）。ただし `temperature_requirement` を読む本番コードは `WindowService` のみで、それは項目 7 の通り本番から呼ばれない。結果に影響しない | 低 |
| 3 | 主経路が `None` のとき `fetch_fallback_weather_payload` でその場予測して 200 を返す | 要判断（一部は違反確定: 検証欠落） | `field_cultivation_climate_data_interactor.rs:264-293`、`:382-467`。正規経路: `weather_prediction_interactor.rs:206-228`、`:277-330`、`:381-422` | 到達する。`GET .../field_cultivations/{id}/climate_data`（公開・非公開の両方。`crates/agrr-server/src/field_cultivation_climate.rs:130-142`）。`work_record_climate_snapshot.rs:60-79` も同じ配線 | 中 |
| 4 | `plan_still_optimizing(...).unwrap_or(false)` | 違反確定（DB エラー分岐のみ）。「status が optimizing でない」「行なし」分岐は仕様上許容 | `crates/agrr-server/src/optimization_chain_phase.rs:33-43`。呼び出し元: `:57`、`optimization_chain_run.rs:434-436`、`task_schedule_generation.rs:218-220` | 到達する。最適化ジョブチェーン全段のガード（`optimization_job_chain.rs:84-300`） | 中 |
| 5 | `FieldsAllocation::allocate` が `total_area <= 0` または作物なしで「デフォルト作物」・面積 `max(100)` を補う | 違反確定 | `crates/agrr-domain/src/cultivation_plan/calculators/fields_allocation.rs:22-35`。呼び出し元の警告ログのみで許容: `cultivation_plan_initialize_interactor.rs:233-242` | 到達しない。`total_area <= 0` は `:132-139` で先に失敗し、作物なしは `public_plan_create_interactor.rs:35-46` で先に失敗する。`FieldsAllocation` の他の呼び出し元は無い（`rg` 確認） | 低 |
| 6 | private plan で計画期間未指定のとき start/end とも `clock.today()` | 違反確定（潜在） | `cultivation_plan_initialize_interactor.rs:194-200`（`:197-198`） | 到達しない。本番の呼び出し元は常に `Some` を渡す: `public_plans.rs:405-412`。`PlanInitializerPort::call` は `Date`（非 Option）を受ける: `public_plans.rs:361-362`。`private_plan_initialize_from_selection_interactor.rs:172-184` も明示日付 | 低 |
| 7 | `WindowService` が温度しきい値走査で常に `eligible: true`（rule `temperature_thresholds`） | 違反確定 | `crates/agrr-domain/src/cultivation_plan/interactors/entry_schedule/window_service.rs:88-113`（`eligible: true` は `:106`）。`fallback.mdc:33` の禁止例に文言が一致 | 到達しない。`WindowService::call` の呼び出し元は自身のテスト（`crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_window_service_test.rs`）のみ。`rg '\bWindowService\b' crates` で確認。型 `DateRange` / `WindowServiceResult` は本番で使用（`entry_schedule_optimize_interactor.rs:14`、`entry_schedule_phase_timeline.rs:8`） | 低（到達不能だが禁止例そのもの） |
| 8 | `serde_json::to_value(..).unwrap_or_else(\|_\| json!([]))` と `presenter.body.unwrap_or_default()` | 違反確定（低。実害なし） | `crates/agrr-server/src/weather_reschedule_proposals.rs:98-100`（同型が `:102-104` にもある）、`:141`。対比: preview は `None` を 500 にしている `:224-231` | `unwrap_or_else`: 型が導出 Serialize のみ（`weather_reschedule_proposal_read.rs:6-23`、`weather_reschedule_proposal_preview_read.rs:9-22`）のため失敗しない。`unwrap_or_default`: interactor は `Ok(())` を返す前に必ず `on_success` を呼ぶ（`weather_reschedule_proposals_list_interactor.rs:66`）ので `None` にならない。ハンドラは到達する | 低 |

### 2.2 依頼範囲外で見つけた同種の握りつぶし（分類のみ。実装スコープ外）

| ID | 箇所 | 内容 | 暫定分類 |
| -- | ---- | ---- | -------- |
| A | `entry_schedule.rs:131-142`（`AgrrCropBuilder::build_from`） | `build_crop_agrr_requirement` の Err と `Ok(None)` の両方を `json!({})` にして最適化デーモンへ渡す。ポートが `Value` 返しで Err を運べない（`crates/agrr-domain/src/shared/ports/crop_agrr_requirement_builder_port.rs:7-10`）。デーモンが `{}` をどう扱うかは未確認 | 違反確定候補（`fallback.mdc:34`）。項目 1・2 と同じ `OptimizeRunner` 内 |
| B | `field_cultivation_climate_data_interactor.rs:308-311` | 進捗計算（agrr デーモン）が Err のとき `{"progress_records": []}` で 200 を返す。進捗ゲートウェイはデーモン失敗を Err にする（`crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:64-73`）。フロントが空の進捗をどう表示するかは未確認 | 違反確定候補。項目 3 と同一ファイル |
| C | 同 `:361-362` | 予測メタデータはあるがストアにペイロードが無いとき `json!({})` として観測値とマージし、観測データのみで 200 になり得る（`merge_cached_with_observed`: `field_cultivation_climate_weather_payload_mapper.rs:79-114`）。`skip_merge` のときは `{}` が `WeatherPayloadInvalidError` になる（`:329-332`、`:503-515`） | 違反確定候補。項目 3 と同一ファイル |
| D | `entry_schedule.rs:445-449`（`stage_rows`）、`:481`（resolve interactor の `.ok()`）、`:567-569`（`list_by_is_reference(...).unwrap_or_default()`） | DB 読取エラーが「作物ゼロの 200」や「crop not found の 404」に化ける | 違反確定候補。項目 1 と同一ファイル |
| E | `field_cultivation_climate.rs:89-92`、`work_record_climate_snapshot.rs:74-77` | ストア読取エラーを `.ok().flatten()` で `None` にし、その場予測（項目 3）へ落とす | 違反確定候補。項目 3 の入口 |
| F | `entry_schedule_optimize_interactor.rs:199-208` | `cultivation_method` が `None` のとき、ステージ名（「定植」「植え付」）から移植/直播を推定 | 要判断。`cultivation_method` は NULL 許容（`crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs:111-` に NULL 行のケースあり）で、マスタ仕様の判断が要る |
| G | `crates/agrr-server/src/account.rs:39` | `serde_json::to_value(export).unwrap_or(json!({}))` | 未調査（本書では周辺コードを読んでいない） |

---

## 3. 項目ごとの対応方針

### 3.1 項目 1: `load_crop_entity_for_optimize` の代替 Crop（違反確定）

**確認した事実**

- 代替 Crop は `CropEntity::new(crop.id(), crop.name(), None, true)`（`entry_schedule.rs:298`）。`cultivation_method` と `variety` は `None`（`crates/agrr-domain/src/crop/entities/crop_entity.rs:23-47`）。`.unwrap()` は名前が空だと panic する（同 `:30-32`）。
- 呼び出し元の `CropWrap` は既に完全な `CropEntity` を持っている（`entry_schedule.rs:98-124`）。show 経路は `find_crop_record_with_stages` = `find_by_id`（`crates/agrr-adapters-sqlite/src/crop/crop_gateway.rs:117-122`）の結果、list 経路は `list_by_is_reference`（`:380-381`、`CROP_SELECT` は `cultivation_method` を含む `:77`）の結果。**それでも再読込するのは、ポート `EntryScheduleOptimizationRunnerPort::call` が `&dyn EntryScheduleShowCrop`（id と name のみ。`entry_schedule_show_interactor.rs:29-34`、`:48`、`entry_schedule_crop_mapper.rs:36-39`）しか渡さないため。** つまり再読込は設計上の欠陥で、代替 Crop はその失敗を隠している。
- 影響: 最適化デーモンゲートウェイは `crop_name` / `crop_variety` を使わない（`crates/agrr-adapters-agrr/src/entry_schedule_optimization_gateway.rs:65` の `let _ = (crop_name, crop_variety);`）。代替 Crop の実害は `cultivation_method == None` になることで、`entry_schedule_optimize_interactor.rs:199-208` がステージ名から移植/直播を推定する。ステージ名に「定植」「植え付」を含まない移植作物は直播として扱われ、`sowing_windows` を持つ `eligible: true` が返り得る（コード読解による推論。再現は未実施 → §5 の RED で確認する）。
- 失敗時の既存の fail-closed 形は用意されている: `failed_result` は `eligible: false` と `reason_parts.source = "agrr_failed"`（`entry_schedule_optimize_interactor.rs:284-296`）。マッパーは `source == "agrr_failed"` を汎用文言にする（`entry_schedule_crop_mapper.rs:200-205`）。i18n キーは `crates/agrr-server/src/locale_catalog.rs:248-254`。

**修正方針（根本原因を直す案を推奨）**

- 案 A（推奨）: 再読込をやめる。`OptimizeRunner::call` が受け取る作物から `cultivation_method` / `variety` を直接得られるようにポートを狭く拡張し、`load_crop_entity_for_optimize` を削除する。DB 読取が無くなるので代替 Crop も不要になる。`public_plan` コンテキストは現状 `cultivation_plan` を import していない（`rg 'crate::cultivation_plan' crates/agrr-domain/src/public_plan` が 0 件）ため、`EntryScheduleOptimizeCrop`（cultivation_plan 側）を流用するか public_plan 側に狭いメソッドを足すかは、実装着手時に依存方向を LAYER-RULES で確認して決める。
- 案 B（最小・案 A が不可のときのみ）: `load_crop_entity_for_optimize` を `Result` にし、Err のとき `OptimizeRunner::call` が `eligible: false`・`source: agrr_failed`・`error_key: "crop_load_failed"` の結果を返す（エラーはログ）。`.unwrap()` も除去する。再読込という無駄は残る。
- どちらでも: `entry_schedule.rs:993-1007` のテスト `load_crop_entity_for_optimize_falls_back_without_db_row` は代替を仕様として固定しているため、削除または反転する。

**許容の文書化案:** なし（許容ではない）。

**ユーザー確認事項:** なし（案 A/B の選択は実装着手時の依存方向確認で決まる）。

### 3.2 項目 2: 温度要件の握りつぶし（違反確定・現状は実害なし）

**確認した事実**

- `entry_schedule_ordered_stage_rows` は `CropStageSnapshot.temperature_requirement` を `.ok().flatten()` で埋める（`entry_schedule.rs:160-181`）。`with_read` は `rusqlite::Result<Option<_>>` を返す（`crates/agrr-adapters-sqlite/src/pool/mod.rs:37-46`）ので、`.ok()` は DB エラーを、`.flatten()` は「行なし」を、区別なく `None` にする。「行なし」は業務上ありえる（温度要件未登録のステージ）が、DB エラーは別物。
- 呼び出し側の最適化 interactor は、このメソッドの Err を `failed_result("crop_stage_load_failed")`（`eligible: false`）にする（`entry_schedule_optimize_interactor.rs:152-157`）。つまり Err を伝播すれば既存の fail-closed に乗る。
- `temperature_requirement` を読む本番コードは無い: `agrr-domain/src` 内の使用は `window_service.rs:57-58, 74-75` と型定義（`crop_stage_snapshot.rs:10`）のみ（`rg temperature_requirement` で確認）。最適化 interactor は `stage_rows` をステージ ID・名前・「定植」名の有無にしか使わない（`entry_schedule_optimize_interactor.rs:159-160`、`:189-192`、`:203-206`、`stage_role_resolver.rs:12-14`）。

**修正方針**

- 項目 7 で `WindowService` を削除する場合（推奨）、温度の読込はデッドコードになる。`load_entry_schedule_temperature`（`entry_schedule.rs:183-203`）、`CropStageSnapshot.temperature_requirement`、`TemperatureRequirementSnapshot`、関連テスト（`entry_schedule.rs:906-953`）を**まとめて削除**する（`project-necessary-code-only.mdc`: 使われないコードを残さない）。握りつぶしも同時に消える。
- 項目 7 を保留する場合のみ: `.ok().flatten()` をやめ、`?` で Err を伝播する（`Ok(None)` は `None` のまま維持）。
- 実装順序は項目 7 → 項目 2（§6）。

**ユーザー確認事項:** 項目 7 の削除可否に従属する（§3.7）。

### 3.3 項目 3: 気象予測の「フォールバック」（要判断。一部は違反確定）

**確認した事実（依頼文の前提との差分を含む）**

1. **`fetch_primary_weather_payload` が `None` を返す条件。** `plan_predicted_weather_present`（= `source.plan_metadata.is_some()`。`field_cultivation_climate_context_snapshot_mapper.rs:34`）が真なら、キャッシュ済み予測を観測値とマージして必ず `Some` を返す（`field_cultivation_climate_data_interactor.rs:320-321`、`:352-380`）。偽なら `invoke_plan_prediction`（`:336-350`）が `weather_prediction_gateway.predict_for_cultivation_plan` を呼ぶ。`None` になるのは後者が `None` のときだけ。
2. **本番配線では後者は常に `None`。** `StoreBackedWeatherPredictionService::predict_for_cultivation_plan` は `plan_metadata.is_none()` なら即 `None`（`crates/agrr-server/src/field_cultivation_climate.rs:75-94`、`work_record_climate_snapshot.rs:60-79` も同一）。`plan_metadata` は `plan_predicted_weather_present` と同じ値なので、偽の経路では常に `None`。したがって**本番では「主経路」は実質スタブで、`fetch_fallback_weather_payload` が唯一の実計算経路**。
3. **フォールバックの中身。** 学習データ（`FixedAnchors`: 基準日から 20 年前の 1/1〜基準日。`field_cultivation_climate.rs:57-73`）を DB から読み、`pred_days = completion_date - training_end_date > 0` なら `prediction_gateway.predict(..., "lightgbm")` で予測して観測値とマージ、そうでなければ観測値のみを `format_for_agrr` で返す（`field_cultivation_climate_data_interactor.rs:390-466`、`field_cultivation_climate_fallback_horizon_policy.rs:3-9`）。**アルゴリズム（`lightgbm`）と学習データ源は正規の `WeatherPredictionInteractor` と同じ**（`weather_prediction_interactor.rs:409`、`:285-293`）。別アルゴリズムへの切替ではなく、遅延計算である。
4. **ただし正規経路にある検証が無い。**

   | 検証 | 正規経路 | フォールバック |
   | ---- | -------- | -------------- |
   | 学習データが空 / 18 年分（`MINIMUM_TRAINING_DAYS`）未満はエラー | あり（`weather_prediction_interactor.rs:347-361`、定数は `reference_farm_weather_readiness_policy.rs:8`） | なし（`:400-406` は件数を見ない） |
   | 予測日数が要求日数に満たなければエラー | あり（`weather_prediction_interactor.rs:415-419`） | なし（`:413-420` は `Some` なら採用） |
   | マージ後データが目標日まで届くこと | あり（`:305-312`） | なし |
   | `valid_weather_payload`（`data` の有無） | 主経路のみ（`field_cultivation_climate_data_interactor.rs:332`） | 通らない（`:264-293`） |

   結果として、学習不足や予測不足のまま 200 と気温・GDD を返し得る（コード読解による推論）。
5. **永続化ステップは常に失敗する疑い（未確認）。** フォールバックは `persist_predicted_weather_if_absent` でその場予測を計画の予測として保存する（`:287`、`:481-501`）。`plan_metadata` が無いときだけ保存するので、フォールバックでは常に保存を試みる。`persist_plan_prediction` は `build_metadata_from_payload(...).ok_or("failed to build prediction metadata")?`（`crates/agrr-adapters-sqlite/src/field_cultivation/plan_predicted_weather_gateway.rs:53-60`）で、これは `prediction_start_date` / `prediction_end_date` キーを要求する（`predicted_weather_cache.rs:24-25`）。フォールバックのペイロードは `merge_training_and_future` または `format_for_agrr` で組まれ、これらのキーを持たない（`field_cultivation_climate_weather_payload_mapper.rs:116-125`、`open_meteo_weather_mapper.rs:53-59`）。よって保存が `Err` になり、interactor は `Err` を返し（`:287` の `?`）、ハンドラは 500 にする（`field_cultivation_climate.rs:227-232`）ように読める。**実行していないため未確認。** §5 の特性化テストで確定する。確定すれば「フォールバックは 200 を返さず 500 になる」ことになり、fail-open ではなく単に壊れた経路である。
6. `FieldCultivationClimateDataInteractor` にはテストが無い（`crates/agrr-domain/test/field_cultivation/` に該当ファイル無し。R4 にも `climate_data` のテスト無し。`rg climate_data crates/agrr-r4-contract` が 0 件）。

**判定の内訳**

| 部分 | 判定 |
| ---- | ---- |
| 3a. 検証欠落のまま 200 を返す（上記 4） | 違反確定（`fallback.mdc:22` の趣旨: 検証不足のもっともらしい成功） |
| 3b. 保存ステップの失敗（上記 5） | 未確認 → 特性化テストで確定 |
| 3c. GET エンドポイントが予測を計算し、さらに永続化する（副作用付き読取）こと自体 | 要判断 |
| 3d. 「主経路」がスタブで、`interactor` 内に予測生成を再実装している構造 | 違反確定候補（正規ロジックの二重実装。R4 `one interactor per use case` の趣旨。断定は §7 の確認後） |

**修正方針（推奨。3c の回答で分岐）**

- 3c を「その場計算は仕様として維持」とする場合: `interactor` 内の再実装（`fetch_fallback_weather_payload` と `persist_predicted_weather_if_absent`）を削除し、正規の `WeatherPredictionInteractor::predict_for_cultivation_plan`（検証と永続化を含む。`weather_prediction_interactor.rs:206-228`）を「主経路」の実体にする。エッジには既に同ロジックを包んだ `OwnedWeatherPredictionService`（`crates/agrr-server/src/adjust_weather_prediction.rs:104-138`）がある。`StoreBackedWeatherPredictionService` を、それを使う実装に置き換える形が第一候補。ポートが `Option<Value>` 返しでエラー種別を失う（`field_cultivation_weather_prediction_gateway.rs:6-`）ため、`Result` 化が要る（未確認: 他の実装・呼び出し元）。
- 3c を「維持しない」とする場合: 予測が未生成なら明示エラー（例: 「予測未生成」）を返す。フォールバックと永続化を削除する。予測はチェーン側（最適化ジョブ）で生成される前提に揃う。
- 追加発見 B・C・E（§2.2）は同一ファイル・同一経路なので、同じ変更で直すかを確認する。

**ユーザー確認事項**

- Q3-1: `GET .../climate_data` は、計画に予測が無いとき予測を生成する（副作用付き読取）仕様を維持するか。維持しない場合、予測未生成時のクライアント向けエラー文言・ステータスの希望はあるか。
- Q3-2: 追加発見 B（進捗計算失敗 → 空進捗で 200）と C（予測ペイロード欠落 → 観測のみで 200）を本課題で同時に直すか。

### 3.4 項目 4: `plan_still_optimizing(..).unwrap_or(false)`（DB エラー分岐のみ違反確定）

**確認した事実**

- 読取は `SELECT status ... WHERE id = ?1`（`optimization_chain_phase.rs:34-41`）。行なしは `QueryReturnedNoRows`、DB 障害はその他の `rusqlite::Error`。`unwrap_or(false)`（`:42`）は両方を「optimizing ではない」にする。
- 「行なし（プラン削除済み）」「status が optimizing 以外（failed・completed）」で停止するのは、ユーザー操作との競合に対する正常な停止であり**許容**。
- **DB エラーで停止すると、無言で止まる。** `run_guarded_optimization_step` は `false` を返して終了する（`:57-59`）。失敗フェーズへの遷移も、エラーログも無い。プランは `optimizing` のまま残る。**滞留したプランを回収する仕組みがあるかは未確認**（`crates/agrr-server/src` を `stale` / `reaper` / `stuck` で検索したところ 4 ファイルが該当したが、内容は読んでいない）。
- さらに `run_plan_finalize_step` は内側の読取が Err のとき `Ok(())` を返す（`optimization_chain_run.rs:434-436`）。これは `run_guarded_optimization_step` の内側（`optimization_job_chain.rs:187-194`）で実行されるため、呼び出し側は成功として `notify_orchestration_on_success(PlanFinalize)` を記録し（`optimization_chain_phase.rs:64-67`）、`"optimization chain finalized"` をログする（`optimization_job_chain.rs:196-198`）。**完了していないプランが完了として扱われる。**

**修正方針**

- `plan_still_optimizing` を `Result<bool, _>` にする。`QueryReturnedNoRows` は `Ok(false)`（許容）、それ以外の DB エラーは `Err`。
- `run_guarded_optimization_step`: `Err` のときはエラーログ（`plan_id` 付き）を出し、チェーンを停止（`false`）する。失敗フェーズへの遷移は既存の best-effort パターン（`:81-99`）に揃えて試みる（同じ DB が壊れていれば遷移も失敗し得るため、ログが最低限の観測点）。
- `run_plan_finalize_step`（`optimization_chain_run.rs:434`）と `run_task_schedule_generation_step`（`task_schedule_generation.rs:218`）も `Err` を `Err(String)` として返す（finalize は「完了として扱う」誤りを直す）。
- 許容分岐の文書化: `plan_still_optimizing` の rustdoc に「行なし・非 optimizing は正常停止」を書く。加えて、テスト名で仕様を表明する（§5）。コメントだけでは解消扱いにしない（`no-convenience-tech-debt.mdc`）ので、上のコード変更が本体。

**ユーザー確認事項:** DB エラー時に失敗フェーズへ遷移を試みる（best-effort）のでよいか。滞留プランの回収機構が別にあるか（未確認事項。あれば失敗遷移を省略できる）。

### 3.5 項目 5: `FieldsAllocation` の代替値（違反確定・到達不能）

**確認した事実**

- `allocate` の先頭分岐は、`total_area <= 0.0 || crops.is_empty()` のとき、`crops.first()` か「デフォルト作物」（`id: 0`、`area_per_unit: 1.0`）を作り、面積を `total_area.max(100.0)` にして返す（`fields_allocation.rs:22-35`）。作物なしで `total_area = 30` なら面積 100 になる。
- 呼び出し元は `total_area <= 0` を先に失敗にする（`cultivation_plan_initialize_interactor.rs:132-139`）。作物なしは公開プラン作成が先に止める（`public_plan_create_interactor.rs:35-46`）。この interactor の直接の呼び出し元は `public_plans.rs:385` のみで、`FieldsAllocation` の呼び出し元は interactor のみ（`rg` 確認）。よって本番では代替分岐に入らない。
- interactor の警告ログ（`:233-240` 「Creating default field.」）は、この代替を前提にした文言で、同じく到達しない。
- `FieldsAllocation` 専用のテストは無い（`ls crates/agrr-domain/test/cultivation_plan` で確認）。

**修正方針**

- `allocate` を不正入力で `Err` を返す形にし（`total_area <= 0` / 作物なし）、代替分岐を削除する。interactor は作物なしを、計画作成前に明示的な失敗結果にする（`total_area` と同じ位置 `:132-139`）。`:233-240` の警告ログを削除する。
- `:245-247` の `invalid_field_area` による `continue`（面積 0 以下のフィールドを黙って飛ばす）は、上の入力検証後は到達しない見込み。本項目で残すか整理するかは実装時に確認する（未確認: `total_area` が 1 未満の小数を受け得るか。ポートは `i64` 渡し: `public_plans.rs:356`）。

**許容の文書化案:** なし。

**ユーザー確認事項:** なし。

### 3.6 項目 6: private plan の計画期間既定値（違反確定・潜在）

**確認した事実**

- `resolve_planning_dates` の private 分岐は、start/end が `None` のとき両方 `clock.today()`（`cultivation_plan_initialize_interactor.rs:194-200`）。期間ゼロ日の計画になる。
- `with_private_planning` の呼び出し元は `public_plans.rs:405-412` のみで、常に `Some` を渡す。他に呼び出しもテストも無い（`rg with_private_planning crates` で確認）。
- 対比: public 分岐の `calculate_public_planning_dates`（`:201-207`）は、公開プランの既定期間を返す別仕様。本項目の対象外（仕様を確認していない）。

**修正方針**

- `with_private_planning` の `planning_start_date` / `planning_end_date` を `Date`（非 Option）にし、`unwrap_or_else` を削除する。型で「未指定」を表現不能にするのが、最も強い fail-closed。
- TDD 上の扱いは §5（到達不能で振る舞いは変わらないため、特性化テストを先に足す）。

**ユーザー確認事項:** 「振る舞い不変リファクタ」として TDD の例外（RED なし）を適用してよいか（`.cursor/rules/tdd-on-edit.mdc` の例外条項。§5.6）。

### 3.7 項目 7: `WindowService` の温度走査（違反確定・到達不能）

**確認した事実**

- 温度しきい値でウィンドウを走査し、`eligible: true` を返す（`window_service.rs:88-113`）。適格日が 0 件でも `true` になる（`sow_ok_dates` / `tr_ok_dates` が空かの検査が無い。`:77-113`）。
- `fallback.mdc:33` と `ARCHITECTURE.md:71` が禁止する形に一致する。ただし `WindowService::call` は本番から呼ばれない（`rg` 確認）。本番の最適化は `EntryScheduleOptimizeInteractor`（agrr の `optimize_period`）で、失敗時は `eligible: false`（`entry_schedule_optimize_interactor.rs:284-296`）。
- 依存: 同ファイルの `DateRange` と `WindowServiceResult` は本番で使われる（`entry_schedule_optimize_interactor.rs:14`、`entry_schedule_phase_timeline.rs:8`、`entry_schedule/mod.rs:11`）。`EntrySchedulePhaseTimeline` 自体にも本番の呼び出し元は見つからなかった（`mod.rs:8` の再エクスポートのみ。`rg` で確認）が、本課題の対象外。
- フィクスチャ文字列 `"window_service"` がテストに残る: `interactors_entry_schedule_phase_timeline_test.rs:87` ほか、`mappers_entry_schedule_crop_mapper_test.rs:204`。

**修正方針**

- `WindowService`（`struct`・`impl`・`day_viable`・`extract_daily_series`・`merge_consecutive_dates`）とそのテストファイルを削除する。`DateRange` と `WindowServiceResult` は別ファイルへ移す。名前は `WindowService` が消えるため、`naming-ules.mdc` に照らして実装時に決める（例: 結果型に見合う名前。`public_plan` 側に別の `EntryScheduleWindowResult`（`entry_schedule_crop_mapper.rs:12`）があるため衝突に注意）。
- テストのフィクスチャ文字列 `"window_service"` を、削除後も意味の通る値に直す。

**ユーザー確認事項:** `WindowService` を削除してよいか（推奨）。保持する場合の理由（将来の用途）が要る。保持は `no-convenience-tech-debt.mdc` に照らし、規約違反コードの残置になる。

### 3.8 項目 8: `weather_reschedule_proposals.rs` の握りつぶし（違反確定・低）

**確認した事実**

- `proposals_to_json`（`:98-100`）と `preview_to_json`（`:102-104`）は `serde_json::to_value(..).unwrap_or_else(..)`。対象型は導出 Serialize の `String` / 列挙 / `serde_json::Value` / `Vec` のみ（`weather_reschedule_proposal_read.rs:6-23`、`weather_reschedule_proposal_preview_read.rs:9-22`）で、`to_value` は失敗しない。ただし失敗すれば「提案なし」の 200 や `{}` になり、利用者に誤解を与える。
- `presenter.body.unwrap_or_default()`（`:141`）は、`on_success` が呼ばれなかった場合に空配列の 200 にする。現状 interactor は必ず `on_success` を呼ぶ（`weather_reschedule_proposals_list_interactor.rs:66`）。同ファイルの preview ハンドラは `None` を 500 にしていて（`:224-231`）、扱いが非対称。
- R4 契約に一覧の形の回帰ガードがある: `crates/agrr-r4-contract/tests/contracts.rs:1122-1180`（空配列、401、他ユーザー、霜予報の提案形）。

**修正方針**

- `to_value` の失敗を握りつぶさず、`internal_error` の 500（既存のエラー形 `{"errors": ["internal_error"]}`: `:150-153`）にする。もしくは型付き `Json<Vec<..>>` を返して axum に直列化させる。どちらも成功時の JSON は不変。
- `:141` は `match presenter.body { Some(p) => .., None => 500 }`（preview `:224-231` と同じ形）にする。
- 同ファイルの `preview_to_json`（`:102-104`）も同時に直す。

**ユーザー確認事項:** なし。

### 3.9 追加発見 A〜G の扱い

本計画の実装スコープには含めない（`project-necessary-code-only.mdc`）。ただし A（`AgrrCropBuilder`）・D（`entry_schedule.rs` 内）は項目 1・2 と同一の `OptimizeRunner` / 同一ファイルの近傍、B・C・E は項目 3 と同一の経路で、同じ差分で直す方が一貫する。**Q3-2 に加え、A・D・E を同時に直すか（別課題にするか）を確認する。**

---

## 4. 共通方針（`unwrap_or` 系の再発防止）

### 4.1 判断基準

- 主経路の失敗は、次の 3 つのどれかにする: 明示エラー（`on_failure` / 4xx・5xx とエラーコード）、`eligible: false` と理由、`501`（`fallback.mdc:25-29`）。
- `Err(_) => デフォルト値` は禁止。「行なし」「`Ok(None)`」が業務上意味を持つ場合のみ `None` を許容し、DB エラーとは別扱いにする（項目 2・4 が該当）。
- `unwrap_or*` の「正常な既定値」（ページ幅の既定など、入力の省略に対するもの。例 `entry_schedule.rs:537-538`）は対象外。対象は「失敗を成功に見せる」ものだけ。

### 4.2 lint・検出スクリプトの妥当性（提案は最小限）

| 案 | 評価 |
| -- | ---- |
| `clippy::unwrap_used` | **不採用。** `unwrap_used` は `.unwrap()` を検出するもので、`unwrap_or_else(\|_\| ..)` や `.ok().flatten()` は検出しない（本課題の 8 項目は 2・3・4・7 以外すべて `unwrap_or*` 系）。一方 `.unwrap()` は `agrr-server` / `agrr-domain` / `agrr-adapters-sqlite` / `agrr-adapters-agrr` の `src` に 830 件あり（`rg -F -c '.unwrap()'` の合計。テストコード込み）、大量の `allow` が要る。加えて CI・スクリプト・`Cargo.toml` に clippy の設定は無い（`grep -rn clippy .github scripts bin Cargo.toml` が 0 件）。導入は依頼外の基盤変更になる。 |
| `scripts/run-architecture-guard-lib.mjs` への 1 ルール追加（`agrr-domain/src/**/interactors/**` で `unwrap_or_else(\|_\|` を禁止） | **本計画では見送り。** 既存のガードは Rust ファイルを走査する構造（`run-architecture-guard-lib.mjs:115`、`:151`、`:167`、`:183`）なので実装は小さいが、該当する `src` の非テスト箇所は現在 4 件（`rg -F 'unwrap_or_else(\|_\|' crates/agrr-domain/src`）で、うち本計画の対象は 1 件（`field_cultivation_climate_data_interactor.rs:311` = 追加発見 B）。残り 3 件（`user_data_export_interactor.rs:36`、`crop_update_interactor.rs:92`、`crop_create_interactor.rs:108`）は本計画の範囲外で、ルール導入には別途の対応が前提になる。 |
| 各項目の RED テストで固定 | **採用。** 再発防止は個別の観測可能な振る舞いのテスト（§5）で担保する。 |

**ユーザー確認事項:** 上記のガードルール追加を別課題として起票するか。本計画では入れない。

### 4.3 ドキュメント

`ARCHITECTURE.md:69-73` と `:106-111` に規範は既にある。追記は不要（`no-convenience-tech-debt.mdc`: 一言追記は解消扱いにならず、`project-necessary-code-only.mdc`: 重複説明は不要）。

---

## 5. TDD 計画

### 5.0 実行スクリプトの制約（重要）

- 使える入口は `test-common` のスクリプトのみ（`.cursor/skills/test-common/SKILL.md:15-27`、`.cursor/rules/test-common-entry.mdc`）。
  - agrr-domain: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh <cargo test の引数>`。中身は `cargo test -p agrr-domain "$@"` と `cargo test -p agrr-migrate --quiet`（`run-test-rust-domain.sh:21-25`）。フィルタは `-- <テスト名>` で渡す。
  - R4 契約: `scripts/run-rust-contract-tests.sh`。
- **`agrr-server` のインラインテスト（`entry_schedule.rs:644-` の `mod tests`、`optimization_chain_phase.rs` の `#[cfg(test)]` など）と `agrr-adapters-sqlite` のテストには、`test-common` のスクリプトが無い。** CI も `agrr-server` の単体テストは実行しない（`.github/workflows/rust-domain-test.yml` は `agrr-domain`・`agrr-migrate`・`agrr-adapters-sqlite -- '_gateway_test'`、`.github/workflows/rails-test.yml:56-58` は `agrr-domain` と `agrr-adapters-sqlite -- '_gateway_test'`）。`.cursor/references/CODE_MODIFICATION_SKILLS.md:22` は HTTP エッジの検証を R4 とする。
- したがって RED を置く層は次の順に選ぶ: (1) agrr-domain の単体テスト（fake ゲートウェイ）、(2) R4 契約、(3) `agrr-adapters-sqlite` の `_gateway_test` 接尾辞のテスト（CI が実行する）。`agrr-server` のインラインテストにしか置けないものは、§7 のとおりランナーの扱いをユーザーに確認する。
- 実行方法: 出力を `./tmp/{UUID}.log` にリダイレクトしてから `grep`（`AGENTS.md`: テストランナーの出力を同じシェルで `grep` / `tail` にパイプしない）。長時間のコマンドは `process-monitor` スキルで完了を待つ。全体実行後に `test-slow-detection` を実施する。

### 5.1 項目 1

案 A（推奨）を選ぶ場合、DB 再読込そのものが消えるため、次を RED にする。案 B の場合は下段。

| 案 | パス | given / when / then | スクリプト |
| -- | ---- | ------------------- | ---------- |
| A | `crates/agrr-domain/test/public_plan/interactors_entry_schedule_show_interactor_test.rs`（既存。`entry_schedule_show_interactor.rs:152-156` の include 先） | given: `cultivation_method = Transplant` を持つ作物と、その作物を記録する fake `EntryScheduleOptimizationRunnerPort`。when: `EntryScheduleShowInteractor::call`。then: runner が受け取る作物から `cultivation_method` と `variety` を読める（ポート拡張の RED。現状はコンパイル不能 = RED）。 | `run-test-rust-domain.sh -- entry_schedule_show_interactor` |
| A | `crates/agrr-server/src/entry_schedule.rs` の `mod tests` | `load_crop_entity_for_optimize_*` の 3 テスト（`:956-1007`）を削除。`CropWrap` が `cultivation_method` をそのまま返すことは、`EntryScheduleOptimizeCrop` の実装（`:112-124`）の既存テストで担保されているかを実装時に確認する（未確認） | R4: `run-rust-contract-tests.sh`（`contracts.rs:4741-4790` の show / list が回帰ガード） |
| B | 同 `mod tests`（`agrr-server` インライン。§5.0 の制約あり） | `load_crop_entity_for_optimize_falls_back_without_db_row`（`:993-1007`）を `..._returns_error_without_db_row` に反転。given: crop 行の無い DB。when: `load_crop_entity_for_optimize`。then: `Err`。RED は現状 `Ok`（代替 Crop）を返すため失敗する | §5.0 の確認結果に従う |

### 5.2 項目 2

| パス | given / when / then | スクリプト |
| ---- | ------------------- | ---------- |
| 項目 7 で削除する場合: RED なし | 使われないコードの削除で振る舞い不変。既存テストの削除（`entry_schedule.rs:906-953`）。R4 の show / list（`contracts.rs:4741-4790`）が回帰ガード | `run-rust-contract-tests.sh` |
| 保持する場合: `crates/agrr-server/src/entry_schedule.rs` の `mod tests`（§5.0 の制約） | given: `crop_test_pool`（`:672-698`）から `temperature_requirements` テーブルを落とした DB とステージ行。when: `entry_schedule_ordered_stage_rows`。then: `Err`（現状は `Ok` で `temperature_requirement: None`。RED） | §5.0 の確認結果に従う |

### 5.3 項目 3

新規: `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_climate_data_interactor_test.rs`。`field_cultivation_climate_data_interactor.rs` の末尾に、既存と同じ `#[cfg(test)] mod ..._test_inline { use super::*; include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/..._test.rs")); }` を足す（パターンは `window_service.rs:238-242`）。interactor は 15 個の `&dyn` 依存を取る（`:45-61`）ため、fake 群の作成が主な作業量になる。

| ID | given / when / then | 現状 | スクリプト |
| -- | ------------------- | ---- | ---------- |
| T3-0（特性化・先行） | given: `plan_metadata = None`、予測ゲートウェイは `Ok(future)` を返す。永続化 fake は、本番ゲートウェイと同じく `prediction_start_date` を持たないペイロードを `Err` にする。when: `call`。then: 現状の挙動（Err か present か）を記録する。**目的は 3b の仮説の確定**（§3.3 の 5） | 未確認 → 確定させる | `run-test-rust-domain.sh -- field_cultivation_climate_data` |
| T3-1 | given: `plan_metadata = None` かつ主経路（`weather_prediction_gateway`）が `None`。when: `call`。then: `Q3-1` の回答が「維持しない」なら `on_error`（予測未生成）で、`present` も永続化も呼ばれない。「維持」なら正規の予測生成が呼ばれる | RED（現状は `present` される） | 同上 |
| T3-2 | given: 学習データが 18 年分未満（または 0 件）で、フォールバックを保持する案。when: `call`。then: `on_error`。（フォールバックを削除する案では不要） | RED | 同上 |
| T3-3 | given: `lightgbm` の予測が要求日数に満たない。when: `call`。then: `on_error`。（同上） | RED | 同上 |
| T3-4（アダプタ） | `crates/agrr-adapters-sqlite/src/field_cultivation/plan_predicted_weather_gateway.rs` 近傍の `*_gateway_test` 接尾辞の関数。given: `merge_training_and_future` が作る形のペイロード。when: `persist_plan_prediction`。then: 現状の結果を記録（`Err` の見込み。§3.3 の 5） | 未確認 → 確定させる | `cargo test -p agrr-adapters-sqlite -- '_gateway_test'`（CI が実行。`test-common` 外である点は §5.0） |
| T3-5（R4・任意） | given: 計画に予測が無く、完了日が過去（`pred_days <= 0`）で、天気 DB がある計画。when: `GET /api/v1/plans/field_cultivations/{id}/climate_data`。then: 現状の HTTP ステータスを記録（500 の見込み。デーモン不要でフォールバックの永続化まで到達できる）。契約に採用するかは Q3-1 の回答後 | 未確認 → 確定させる | `run-rust-contract-tests.sh` |

### 5.4 項目 4

`optimization_chain_phase.rs` は `agrr-server` のインラインテスト（§5.0 の制約）。既存のテスト: `plan_still_optimizing_is_true_only_for_optimizing_status`（`:273-297`）、`run_guarded_optimization_step_skips_when_plan_not_optimizing`（`:300-321`）。

| ID | given / when / then | 現状 |
| -- | ------------------- | ---- |
| T4-1 | given: `cultivation_plans` テーブルを落とした DB。when: `plan_still_optimizing`。then: `Err` | RED（現状 `false`） |
| T4-2 | given: 存在しない `plan_id`。when: `plan_still_optimizing`。then: `Ok(false)`（許容分岐の表明） | GREEN のまま（回帰ガード） |
| T4-3 | given: DB エラー。when: `run_guarded_optimization_step`。then: step は実行されず `false`。エラーが `Err` として観測できる（ログ／戻り値の形は実装時に決める） | RED |
| T4-4 | given: DB エラー。when: `run_plan_finalize_step`。then: `Err(String)`（現状 `Ok(())` で完了扱いになる） | RED |

### 5.5 項目 5

| パス | given / when / then | 現状 |
| ---- | ------------------- | ---- |
| 新規 `crates/agrr-domain/test/cultivation_plan/calculators_fields_allocation_test.rs`（`fields_allocation.rs` に include を追加） | 作物なし・`total_area = 30` → `Err`。`total_area <= 0` → `Err`。作物 2 件・`total_area = 250` → 通常の配分（特性化。GREEN 維持） | 前 2 つは RED（現状は面積 100 / 代替作物を返す） |
| `crates/agrr-domain/test/cultivation_plan/interactors_cultivation_plan_initialize_interactor_test.rs`（既存。`:171-` の `returns_failure_when_total_area_is_not_positive` と同型） | given: 作物 0 件・`total_area = 50`。when: `call`。then: 失敗結果で、トランザクション内の `create` が呼ばれない | RED |

スクリプト: `run-test-rust-domain.sh -- fields_allocation` と `-- cultivation_plan_initialize`。

### 5.6 項目 6

| パス | given / when / then | 備考 |
| ---- | ------------------- | ---- |
| `interactors_cultivation_plan_initialize_interactor_test.rs` | given: `with_private_planning` で明示日付を渡す。when: `call`。then: 作成属性がその日付になる（特性化。現状も GREEN） | `with_private_planning` の呼び出しテストは現在無い（`rg` 確認）。型を `Date` にした後も GREEN |
| RED | 作れない。到達不能で、型で未指定を排除するため、「未指定」を表す入力が存在しなくなる | 振る舞い不変リファクタとして TDD の例外を適用するため、Q（§3.6）で確認する。代替として `Option` を残し「未指定なら失敗結果」とする案は RED を作れるが、型で排除するより弱い |

スクリプト: `run-test-rust-domain.sh -- cultivation_plan_initialize`。

### 5.7 項目 7

RED なし（使われないコードの削除で、本番の振る舞いは不変）。削除後に `run-test-rust-domain.sh` 全体がコンパイル・GREEN であることが検証。`WindowService::call` を呼ぶテスト群（`interactors_entry_schedule_window_service_test.rs`）は削除する。型の移動先でテストが必要な既存の検証が失われないよう、`DateRange` / `WindowServiceResult` を使う既存テスト（`interactors_entry_schedule_phase_timeline_test.rs`、`interactors_entry_schedule_optimize_interactor_test.rs`、`mappers_entry_schedule_crop_mapper_test.rs`）が GREEN のまま通ることを確認する。

### 5.8 項目 8

RED なし。失敗を作れない（導出 Serialize のみ、`on_success` は必ず呼ばれる）ため、振る舞い不変リファクタ。R4 契約 `contracts.rs:1122-1180`（一覧の空配列 / 401 / 他ユーザー / 提案形）が回帰ガード。preview の R4 テストの有無は未確認（`rg 'preview' crates/agrr-r4-contract/tests/contracts.rs` を実装時に確認し、無ければ最小の契約を 1 本足すか判断する）。

スクリプト: `scripts/run-rust-contract-tests.sh`。

---

## 6. 実装ステップ

`crates/agrr-server/**`・`crates/agrr-domain/**` を変更したら、Docker で検証する前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する（`.cursor/rules/docker-dev-agrr-server-rebuild.mdc`）。

| 順 | 内容 | コミット | 根拠 |
| -- | ---- | -------- | ---- |
| 0 | ユーザー確認（Q3-1、Q3-2、§3.4、§3.6、§3.7、§7 のランナー）。回答が無い項目は着手しない（`evidence-before-design-and-implementation.mdc`: 仮説の段階で設計しない）。 | なし | — |
| 1 | 項目 3 の特性化テスト（T3-0、T3-4、T3-5）で 3b を確定する。ここで得た事実を本書 §3.3 に反映してから修正に進む。 | 特性化テスト 1 つ | 到達する中重大度で、かつ前提が未確認のため最優先で確定させる |
| 2 | 項目 3 の修正（RED T3-1〜T3-3 → 実装 → GREEN）。Q3-1 と Q3-2 の回答に従い、B・C・E を含めるかを決める。 | 1 コミット（テスト + 実装） | 到達する。ユーザー影響が最大 |
| 3 | 項目 1 の修正（案 A 優先）。A・D を含めるかは確認結果に従う。 | 1 コミット | 到達する |
| 4 | 項目 4 の修正（T4-1〜T4-4）。 | 1 コミット | 到達する。プランが完了扱いで滞留する誤りを含む |
| 5 | 項目 7: `WindowService` 削除と型の移動。 | 1 コミット | 項目 2 の前提 |
| 6 | 項目 2: 温度読込の削除（項目 7 に従う）。 | 1 コミット | 項目 7 に依存 |
| 7 | 項目 5（RED T5 → 実装 → GREEN）。 | 1 コミット | 到達不能・低 |
| 8 | 項目 6（型の必須化）。 | 1 コミット | 到達不能・低 |
| 9 | 項目 8。 | 1 コミット | 到達不能・低 |
| 10 | 全体検証: `run-test-rust-domain.sh`（全体）、`scripts/run-rust-contract-tests.sh`、`scripts/run-architecture-guard.sh`、`test-slow-detection`。 | なし | `rails-testing-workflow.mdc`: 個別 GREEN の後に全体実行 |

コミットは項目ごとに 1 つ（論理変更ごと）。項目 5〜9 は到達不能でも規約違反の残置になるため、`no-convenience-tech-debt.mdc` に従い先送りしない。順序は依存（7 → 2）と到達性・重大度で決めたもので、日数の見積りはしない。

---

## 7. リスク・未確定事項

| # | 内容 | 扱い |
| - | ---- | ---- |
| R1 | **`agrr-server` インラインテストの正式ランナーが `test-common` に無い**（§5.0）。項目 1（案 B）、2（保持案）、4 の RED は `agrr-server` のインラインにしか置けない | ユーザー確認。選択肢: (a) `test-common` に `agrr-server` 用の入口を足す（別課題）、(b) 判定ロジックを domain へ寄せて `run-test-rust-domain.sh` で RED にする（項目 4 は状態読取ポートが要り、変更が大きい）、(c) 既存のインラインテスト（`entry_schedule.rs` の `mod tests` など）の慣行に従い、実行方法を別途明記する |
| R2 | 項目 3b（永続化が常に失敗する疑い）は**コード読解のみで未実行** | T3-0 / T3-4 / T3-5 で確定するまで、修正の中身を確定しない |
| R3 | 項目 3 のポート変更（`FieldCultivationWeatherPredictionServiceGateway::predict_for_cultivation_plan` が `Option<Value>` 返し）の影響範囲は未確認。呼び出し元は `field_cultivation_climate_data_interactor.rs:344` と、実装は `field_cultivation_climate.rs:80`、`work_record_climate_snapshot.rs:65` の 2 つ（`rg` で確認した範囲） | 実装着手時に `rg` で全数確認 |
| R4 | 項目 1 の案 A は `public_plan` → `cultivation_plan` の依存を作る恐れ（現状は無い） | 実装着手時に LAYER-RULES（R1・R8）で確認し、狭いポートを `public_plan` 側に持つ案も比較 |
| R5 | 項目 4 で DB エラー時に失敗フェーズへ遷移できない場合がある（同じ DB が壊れている） | ログを最低限の観測点にする。滞留プランの回収機構は未確認 |
| R6 | 項目 7 の削除で `EntrySchedulePhaseTimeline` が孤立する可能性。本番の呼び出し元が見つからない（`mod.rs:8` の再エクスポートのみ） | 本課題の対象外。削除するかは別課題として起票を提案 |
| R7 | 項目 1 の影響（移植作物が直播扱いになる）はコード読解による推論。再現は未実施 | 案 A/B のどちらでも RED は §5.1 で作れる。影響の再現は任意 |
| R8 | 追加発見 A〜G の実害・網羅性は未確認。`unwrap_or*` / `.ok()` の全数調査は本書では行っていない（`unwrap_or_else(\|_\|` は `crates/agrr-server/src` に 18 ファイル、`agrr-domain/src` の非テストに 4 件あることのみ確認） | 同種の全数調査が必要なら、別課題（05 fail-closed-critical との突合が先。§9） |
| R9 | `ARCHITECTURE.md` に fail-closed の節が 2 つある（`:69-73`、`:106-111`）。内容は同趣旨 | 本課題の対象外（文書の整理は 09 stale-design-docs の範囲かを確認） |

---

## 8. 受け入れ条件

### 8.1 共通

- `.cursor/skills/test-common/scripts/run-test-rust-domain.sh`（全体）が GREEN。
- `scripts/run-rust-contract-tests.sh` が GREEN。
- `scripts/run-architecture-guard.sh` が `run-architecture-guard: OK`。
- `test-slow-detection` の遅延検知を通過。
- `crates/*` を変更した場合、`rebuild-restart.sh` 後に該当エンドポイントを確認した。
- 各項目の RED が、意図した理由で失敗することを確認してから GREEN にした記録がある（RED が作れない項目 5〜9 の例外は、確認済みの回答に従う）。

### 8.2 項目別

| # | 条件 |
| - | ---- |
| 1 | `entry_schedule.rs` に `is_reference: true` の代替 `CropEntity` 生成が残らない（`rg 'CropEntity::new' crates/agrr-server/src/entry_schedule.rs` の本番コードが 0 件）。DB 読取失敗は `eligible: false` か明示エラーになる（案 B の場合）。または再読込自体が無い（案 A）。 |
| 2 | 温度要件の `.ok().flatten()` が残らない。読込が残る場合、DB エラーは Err で伝播し、「行なし」だけが `None`。 |
| 3 | 3b が確定し、その結果に応じた修正が入っている。検証（学習不足・予測不足）を欠いたまま 200 を返す経路が無い。Q3-1 の回答どおりの仕様（維持 / 予測未生成エラー）が R4 かドメインテストで表明されている。 |
| 4 | DB 読取エラーで、プランが無言で `optimizing` に滞留することも、完了として記録されることも無い。「行なし・非 optimizing は正常停止」がテストで表明されている。 |
| 5 | `FieldsAllocation` に代替作物・`max(100)` の代替が無く、不正入力は `Err`。作物なしは interactor が計画作成前に失敗にする。 |
| 6 | `with_private_planning` が計画期間を必須の `Date` で受け、`unwrap_or_else(\|\| clock.today())` が残らない。 |
| 7 | `WindowService` と `temperature_thresholds` が `crates/` に存在しない（`rg` で 0 件）。`DateRange` / `WindowServiceResult` 相当の型は本番で引き続き使われる。 |
| 8 | `weather_reschedule_proposals.rs` に `unwrap_or_else(\|_\| json!(..))` と `unwrap_or_default()` が残らない。R4 の一覧契約（`contracts.rs:1122-1180`）が不変。 |

---

## 9. 関連課題との依存

`docs/spec-defects/` には本書作成時点で 01〜04 のみが存在する（`ls` で確認）。05 以降は未作成のため、下表の 05・07〜11 は**依頼文の題名からの推定で、内容は未確認**。01・02・03・04 は題名から本課題と無関係と判断した（03・04 は先頭部を読んだ範囲でも API キー認証の話）。

| 番号 | 題名 | 関係 |
| ---- | ---- | ---- |
| 01 resource-limit-bypass | 資源上限の回避 | 独立。 |
| 02 contact-recaptcha | 問い合わせの reCAPTCHA | 独立。 |
| 03 api-key-scope-docs | API キースコープの文書 | 独立。 |
| 04 api-key-query-auth | API キーのクエリ認証 | 独立（本書と扱う箇所は重ならない）。 |
| 05 fail-closed-critical | fail-closed の致命的な違反 | **同系統。重複・取りこぼしの突合が必要。** 本書の追加発見 A〜G と 05 の対象を突き合わせ、同じ箇所を二重に直さないようにする。05 が未作成のため、着手前に確認する。 |
| 07 frontend-error-contract | フロントのエラー契約 | **依存の可能性。** 項目 1（`eligible: false` と `reason_parts` の既存形を使う）、項目 3（`climate_data` のエラーは `{success:false, message}` で、HTTP ステータスは `message` の部分一致で決まる: `field_cultivation_climate.rs:102-116`）、項目 4・8（`{"errors":[..]}`）でエラー応答が変わる。新しいエラー文言を足すと `status_for_message` の部分一致に影響するため、07 の契約と合わせる。フロントの `climate_data` の消費側（`frontend/src/app/adapters/plans/field-climate-api.gateway.ts:22`）のエラー処理は未確認。 |
| 08 openapi-gaps | OpenAPI の欠落 | **関係あり。** `docs/api/openapi.yaml` に `entry_schedule`・`climate_data`・`weather_reschedule` のパスは存在しない（`grep` で 0 件）。本課題でエラー形を決めた後に、載せるかを 08 で扱う。別の OpenAPI ファイルの有無は未確認。 |
| 09 stale-design-docs | 古い設計文書 | 弱い関係。本課題は文書追記を必要としない（§4.3）。`ARCHITECTURE.md` の fail-closed 節の重複（R9）は 09 の範囲かを確認。 |
| 10 authorization-consistency | 認可の一貫性 | 独立。項目 3 の `climate_data` 経路には認可チェックがあるが（`field_cultivation_climate_data_interactor.rs:122-157`）、本計画は触らない。 |
| 11 low-priority-misc | 低優先の雑多 | 項目 5・6・8（到達不能・低）は、ここへ回したくなるが、`no-convenience-tech-debt.mdc` により規約違反の残置になるため本課題で扱う。 |
