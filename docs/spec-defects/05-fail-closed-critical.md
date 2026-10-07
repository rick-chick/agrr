# 05 fail-closed 違反（確度高）: agrr 失敗時の成功形レスポンス 2 件

**状態:** 対応計画（改訂 3: 07 の最新エラー契約（`errors` 配列＋任意の `error_code`）への整合と、master に入った特性化テスト #1337〜#1344 との関係の整理を反映。未着手・コード変更なし）。
**根拠の扱い:** 本書の事実は `master` のコードを読んで確認したもの（`file:line` 付き）。改訂 2 までは 2026-09-29 時点の `cdfd21ac6`、改訂 3 は 2026-10-07 時点の `3de664648`（#1344）で再確認した。`git diff cdfd21ac6 HEAD -- crates` の結果、本書が参照するソース本体（`src/`）の差分は追記された `#[cfg(test)]` の `include!`（`field_cultivation_climate_data_interactor.rs:642-649`、`fields_allocation.rs`、`optimization_chain_phase.rs` のテスト）だけで、ソースの `file:line` はずれていない。テストファイルの `file:line` は #1337〜#1344 で動いたため改訂 3 で更新した。実行して確認していないものは「未確認」と明記する。`agrr` バイナリ本体は本リポジトリ外のため、その挙動に関する記述は「未確認」または既存スキル文書の引用として区別する。既存テストは読解で確認しており、今回は実行していない。

## 0. 決定事項

### 0.1 fail-closed を厳格に適用する（ユーザー語「厳格」からの解釈）

**出典:** ユーザー指示は「厳格」の一語である。本書はこれを次のとおり解釈し、以降の設計をすべてこの解釈に従って確定する。ユーザーが個別に例外を示さない限り、例外を設けない解釈である。

- **禁止:** 主経路（agrr progress、作物要件の取得）の失敗・不完全を、代替値・空値・手計算などの別アルゴリズム・直前の古い値で埋めて、成功形の応答（HTTP 2xx、`success: true`、永続化成功）を返すこと。
- **許容:** 失敗の明示。具体的には `ErrorDto` 相当の失敗出力（domain の出力ポート経由）、`eligible: false`（`entry_schedule` の既存契約。200 の本文で表現し `reason_parts.error_key` を付ける）、適切な HTTP ステータス。
- **一過性でも例外にしない:** サーバ側で「待てば直る」ことを理由に縮退表示や代替計算を入れない。フロントの backend warmup 再試行は既存の別機構であり、サーバ方針の根拠にしない（影響は 3.A-6 に記載）。
- **対象の境界:** 本書が禁止する「代替」は「主経路の失敗を隠す成功形データ」に限る。表示範囲フィルタ後に該当日が無い、といった表示上の絞り込みは対象外。ただし「ドメイン上正当な不在」は、3.A-2 のように実装で確認できる基準として明文化したものに限って認める。

### 0.2 厳格方針から自動的に確定した事項

| # | 確定事項 | 改訂前の状態 | 本文 |
|---|----------|--------------|------|
| D1 | agrr progress が `Err` のとき、手計算 GDD にも空 progress にも落とさず、typed な失敗で明示的に失敗させる | 「失敗として扱う案（推奨）」 | 3.A-1 |
| D2 | agrr が成功でも、空・不正形・期間外の結果は失敗にする。基準（F1〜F3）を明文化した。正当な 0 件は現行ドメインに存在しない | ユーザー確認 2 | 3.A-2 |
| D3 | 作物要件が不完全（有効 stage 0 件、または `base_temperature` の基準 stage に温度要件なし）のとき、climate_data は明示エラー、entry_schedule は `eligible:false` にする。代替値 `10.0` は撤廃する | climate 側は未言及 | 3.A-3、3.B |
| D4 | 手計算関数 `calculate_gdd_manually` と `debug_info.using_agrr_progress` を削除する。他の利用者は無い | 削除案 | 3.A-4 |
| D5 | 作業記録が手計算値・古い値・空値を成功として保存する経路を残さない。progress 不可の `lookup` は typed エラーとして create / update に伝播させる | ユーザー確認 3（推奨は「null で保存続行」） | 3.A-5 |
| D6 | HTTP ステータスは typed な失敗種別（enum）で決める。新規の失敗に `status_for_message` の文字列推定を使わない。gateway の失敗も文字列でなく型で分類する | 専用ポートメソッド案 | 3.A-6 |
| D7 | `entry_schedule` の作物要件 port を `Result` 化し、`.ok().flatten().unwrap_or(json!({}))` を撤廃する。取得失敗・未定義は agrr を呼ばず `crop_requirement_error` | 案 B-1 推奨 | 3.B、5.B |
| D8 | 隣接する同型の握りつぶし（B-4）は放置しない。厳格方針では違反確定であり、06 §3.1 の設計に従って同時に是正する | ユーザー確認 5 | 2.B-4、10 章 |

### 0.3 ユーザー確認が残る事項

厳格方針で決まらないものだけを残す。コード値、UX 影響、設計判断が対象。

| # | 確認内容 | 推奨 | 影響 |
|---|----------|------|------|
| U1 | HTTP ステータスのコード値（失敗種別ごと）。種別の分け方は D6 で確定済み | `ProgressDaemonUnavailable` 503、`ProgressExecutionFailed` 500、`ProgressResultInvalid` 500、`CropRequirementIncomplete` 422（根拠と代替は 3.A-6） | フロントの GET は 502/503 を最大約 60 秒再試行する。07 の F1 後は、503 が再試行されるかが本文の `errors[0]` で決まる（0.4、3.A-6） |
| U2 | 作業記録: progress 不可のとき、作成・更新自体を失敗にする（推奨）か、`gdd_at_actual`・`weather_snapshot` を null にして保存を続行するか | 作成・更新を失敗にする。null 保存は「空値で成功形」に当たり、厳格方針（0.1）と両立しない | agrr 障害中は作業記録を保存できない（UX 影響。3.A-5） |
| U3 | 作業記録の `lookup` の認可コンテキスト欠陥（2.A-5）を本件で直すか、10 authorization-consistency に送るか | 本件では typed 失敗の伝播のみ行い、欠陥の修正は U2 の回答後に同一変更セットで行うか 10 に送るかを決める。修正すると本番で `gdd_at_actual` の記録が始まり、保存のたびに agrr 呼び出しが発生する | 挙動が変わる。R4 環境（agrr daemon なし）で作業記録作成が失敗し得る（未確認） |
| U4 | 天候欠損で progress の先頭日が `start_date` より後のとき（実データからの部分的な積算）を失敗にするか | 失敗にしない。値は代替でなく実データの積算であり、3.A-2 の F1〜F3 の対象外。ただし表示が過小になり得る（8 章 7） | 厳格に解すると多くの計画で失敗表示になり得る（頻度は未確認） |
| U5 | 案 B-1（port を `Result` 化）か案 B-2（port を廃止し既存 gateway を使う）か（5.B） | B-1 | B-2 は波及が大きい |
| U6 | フロントで 503 化後に「空表示」になる 3 利用者（2.A-4）の受容 | 受容する。手計算のグラフが出るより規約上正しい | 利用者に見える変化 |

### 0.4 エラー契約: 07 の最新版との整合（第 2・3 回決定の反映）

改訂 2 までの失敗本文（`{"success": false, "error_key": ..., "message": ...}` の暫定案）は、07 の確定契約に未追随だった。07 の最新版（[`07-frontend-error-contract.md`](07-frontend-error-contract.md) の §0.2 `errors` への統合、§0.3 旧キー削除、§3.3 契約、§3.6 `api_error.rs`、§10 の 05 の行）を読み、次のとおり合わせる。ユーザー決定は 07 側の「errors」「削除」で、本表の写像（`error_code` の値、キー名、再試行の扱い）は 05 の設計判断である。

| 項目 | 07 の確定 | 05 の対応 |
|------|-----------|-----------|
| 失敗本文の形 | 4xx / 5xx は `errors`（1 件以上の非空文字列の配列）を必ず持つ。付加情報として `error_code` / `field_errors` を許す（07 §3.3 C1・C5・C6）。`error`（単数）と `message` は失敗の主メッセージにしない（C4）。`success: false` などは付加情報として許容（C8） | `{"success": false, "errors": ["<reason 由来の i18n キー>"], "error_code": "<reason の snake_case>"}`。`message`・`error`・`error_key` は付けない（`errors[0]` のキーが `error_key` の役割を兼ねるため、同じ値の二重化を避ける）。`success: false` は成功本文（`success: true`）との対応を保つ付加情報として残す |
| 失敗種別ごとの値 | `error_code` は自由文字列（C6）。既存の名称・値は維持 | `ProgressDaemonUnavailable` → `errors: ["api.errors.climate_progress_daemon_unavailable"]`、`error_code: "progress_daemon_unavailable"`。同様に `ProgressExecutionFailed`（`..._progress_execution_failed`）、`ProgressResultInvalid`（`..._progress_result_invalid`）、`CropRequirementIncomplete`（`api.errors.climate_crop_requirement_incomplete` / `crop_requirement_incomplete`）。`errors[0]` は翻訳済み文言でなくキー（`PassthroughTranslator` と同じ扱い。フロントは `control.error \| translate` で表示する: `plan-field-climate.component.ts:118-119`） |
| 組み立て方 | `crates/agrr-server/src/api_error.rs`（S0）の `api_error_with_code` などを使う。`Legacy` は移行期間（S1）だけの引数で、新規の失敗は `Legacy::None`（07 §3.6、§10 の 05 の行(5)）。S-T6 のアーキテクチャガードは `crates/agrr-server/src` での `"error"` / `"message"` の直書きを検出する（Q9 の既定） | 新規の失敗本文は `api_error_with_code(status, key, code, Legacy::None)` に `success: false` を `with_extra` で足して作る。`json!({"message": ...})` を新規に書かない。`api_error.rs` は現時点で存在しない（`ls` で確認）ので、05 の server 変更は 07 の S0 の後（7 章） |
| 同一エンドポイントの既存分岐 | `field_cultivation_climate.rs:153-242` の `{"success": false, "message": ...}` 5 箇所は 07 の区分 B で、S1 で `errors` を足して `message` を併記し、S2 で撤去 | 05 は既存分岐（`on_error` 経由の前提条件・認可・作物不在・データなし）に触れない。S1〜S2 の間は、同じ endpoint で既存分岐が `message` 併記、新規の失敗が `errors` + `error_code` のみとなる。S2 後に揃う |
| HTTP ステータス | 07 は変えない（C9。課題 10 の範囲） | 05 の U1 の値（503 / 500 / 500 / 422）をそのまま使う |
| フロントの読み取り | `errors` 1 系統。`apiErrorMessage` で読む（07 §3.7）。`load-field-climate.usecase.ts:86-93` は F1 で置換 | 現行コードも `err.error.error ?? err.error.errors?.join(', ')` で、新規本文には `error` が無いため `errors` の結合文字列（= キー）が `onError.message` に入る。F1 後も同様。本件のフロント変更は不要（現行コードの読解。実画面は未確認） |
| 警告分類（backend warmup） | F1 後、`backend-warmup.ts:74-106` は `error` の代わりに `errors[0]` を見る。判定規則は同じ（503 で本文コードがあり daemon 系の文字列を含まなければ「明示的な失敗」で再試行しない）。05 の新しい 503 は「`errors[0]` が daemon 系の文字列を含めば警告として GET が再試行、含まなければ再試行されない。どちらにするかは 05 が決める」（07 §8 R22、§10） | **決定:** `ProgressDaemonUnavailable` の `errors[0]` に `daemon_unavailable` を含める（上表のキー名）。`isComputeEngineWarmupMessage`（`backend-warmup.ts:31-38`）は `daemon_unavailable` の部分一致で真になるため、GET は従来どおり再試行される。これは 3.A-6 の「daemon 起動待ち」の意図と一致する。`ProgressExecutionFailed` / `ProgressResultInvalid` は 500 で再試行の対象外、`CropRequirementIncomplete` は 422 で対象外。`errors[0]` で先に分類されるため、`error_code` に `daemon_unavailable` が含まれても分類は変わらない（`isBackendWarmupHttpError` は `isEntryScheduleWeatherHttpError` を先に判定する: `:108-113`）。F1 前（現状）は climate の本文に `error` キーが無いので、`errors[0]` の内容にかかわらず 503 は再試行される |
| entry_schedule（B） | 07 の契約は 4xx / 5xx の失敗本文が対象 | B は 200 の本文の `eligible: false` + `reason_parts.error_key` で、失敗本文ではないため 07 の契約の対象外。変更なし |

## 1. 概要と重大度

`ARCHITECTURE.md` の "Fail-closed and fallback policy"（69-73 行付近）と `.cursor/rules/fallback.mdc`（原則 1-3、禁止例「Gateway / Adapter で例外を握りつぶし、デフォルト値で『成功っぽく』見せる」）に反して、主経路（agrr）が失敗しても成功形の応答を返している箇所が 2 件ある。

| ID | 場所 | 症状 | 重大度 |
|----|------|------|--------|
| A | `crates/agrr-domain/src/field_cultivation/interactors/field_cultivation_climate_data_interactor.rs` `build_climate_output` | agrr `progress` 失敗でも `success: true` を返す。さらに mapper が別アルゴリズム（手計算 GDD）で積算温度を埋める。作物要件の欠落時は `base_temperature` に代替値 `10.0` を使う | 高（誤った農業判断の表示。作業記録の `gdd_at_actual` への永続化は現構成では到達しない読解で、潜在的なリスク。2.A-5） |
| B | `crates/agrr-server/src/entry_schedule.rs` `AgrrCropBuilder::build_from` | 作物要件の取得失敗・未存在時に `{}` のまま agrr 最適化へ進む | 中（最終的には `eligible: false` になる経路が多いが、原因が隠れる。`{}` を agrr が受理した場合の挙動は未確認） |

重大度の根拠: A は「失敗を成功として表示する」うえ、失敗が HTTP 層・フロントのどこにも伝わらない（後述 2.A）。B は既存の `eligible:false` マッピングが働くため誤った適期表示の確率は低いが、fail-closed 規約の原則 2（明示エラーまたは `eligible:false`）を原因付きで満たしていない。

### 依頼文からの訂正（コード再確認の結果）

1. 依頼文は A を「積算 GDD 空の成功形 JSON を返す」と要約していたが、実際はそれより悪い。`unwrap_or_else` が返す `{"progress_records": []}` は mapper の `build_daily_gdd` で「progress_records が空 → `calculate_gdd_manually`」に分岐し（`field_cultivation_climate_data_mapper.rs:187-188`）、**非空の `gdd_data`** が生成される。つまり空ではなく、別算出の値が成功として返る（2.A-3）。
2. 改訂前の本書は「progress 失敗時に手計算値が `work_records.gdd_at_actual` に保存され得る」と書いていたが、コード読解ではその経路は現構成で到達しない（作業記録側のスナップショット取得が常に認可拒否で空になる。2.A-5）。潜在リスクとして扱いを改めた。
3. 改訂前の本書は「ログで区別する」「logger.warn で原因を残す」としていたが、A も B も本番配線の logger は `NoopLogger` で何も出力しない（2.A-1、2.B-3）。ログを根拠にする前に配線の変更が必要。

## 2. 現状（確認済み事実）

### 2.A field cultivation climate_data

**A-1 握りつぶし箇所**

- `field_cultivation_climate_data_interactor.rs:296-313` `build_climate_output` は `Result` を返さず、`:308-311` で `climate_progress_gateway.calculate_progress(...)` の `Err` を `.unwrap_or_else(|_| json!({ "progress_records": [] }))` で潰す。エラー内容はログにも出ない（この関数は logger を使っていない）。
- 呼び出し元 `assemble_climate_data`（`:258-275`）と `assemble_climate_data_from_fallback`（`:277-294`）は `build_climate_output` の戻りを常に `Ok(Some(...))` で包む。よって `call`（`:111-220`）の `match assemble_climate_data(...)`（`:200-211`）は progress 失敗を検知できず、`:218` の `self.output_port.present(filtered)` に到達する。
- 本番配線の logger は `NoopLogger`（`crates/agrr-server/src/field_cultivation_climate.rs:191`、`crates/agrr-server/src/work_record_climate_snapshot.rs:113`）で、`info` / `warn` / `error` / `debug` はすべて空実装（`crates/agrr-server/src/adapters.rs:8-15`）。同じ `adapters.rs:19` に stderr へ書く `StderrLogger` があり、`weather_reschedule_proposals.rs:184` などが使っている。

**A-2 gateway 側は失敗を表現できている**

- trait `FieldCultivationClimateProgressGateway::calculate_progress` は `Result<Value, Box<dyn Error + Send + Sync>>`（`crates/agrr-domain/src/field_cultivation/gateways/field_cultivation_climate_progress_gateway.rs:5-11`）。
- 実装 `FieldCultivationClimateAgrrGateway`（`crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:64-73`）は daemon 未起動を `map_agrr_daemon_error`（`crates/agrr-adapters-agrr/src/daemon_unavailable.rs:40-46`）で `DaemonUnavailableError`（Display は `"daemon_unavailable"`）に、それ以外は `AgrrDaemonError` にして返す。テスト済み（`crates/agrr-adapters-agrr/tests/field_cultivation_climate_gateway_test.rs:8-32, 36-60`）。`DaemonUnavailableError` と `AgrrDaemonError` は adapter crate の型で、domain からは downcast できない（adapter が domain に依存する向きのため）。
- 同 trait 実装は task schedule 側も使う。`TaskScheduleProgressAgrrGateway`（`task_schedule_progress_gateway.rs:56-61`）は `err.to_string()` を取って domain の `TaskScheduleSyncError`（`AGRR_UNAVAILABLE`）に包む（`:41-43`）。よって Display 文字列 `"daemon_unavailable"` は task schedule 側の契約でもあり、型を変える場合も文字列は保つ必要がある。
- ただし成功時も `normalize_progress_result`（`progress_daemon_normalize.rs:12-34`）は、`progress_records` も `daily_progress` も無い未知形の payload を `:33` で `empty_progress_result()` に丸める。`daily_progress: []` も同様に空（`:19-21`、テスト `:90-95`）。すなわち「agrr は成功したが 0 件」と「未知形」も空 `progress_records` として domain に届く。
- 各 record の `cumulative_gdd` が無い場合、normalizer は `Null` にする（`:42-47`）。後段の mapper は `Null` を `unwrap_or(0.0)` で `0.0` に置換する（`field_cultivation_climate_data_mapper.rs:230-232`、前日値は `:236-239`）。これも代替値である。

**A-3 mapper の別アルゴリズムと代替値（fallback.mdc 原則 3 違反）**

- `field_cultivation_climate_data_mapper.rs:187-188`: `progress_records.is_empty()` のとき `calculate_gdd_manually(weather_data_records, base_temp)`（`:265-292`）を使う。`(平均気温 - base_temperature).max(0)` の単純累積で、`current_stage` は `Null`（`:288`）。agrr 経路は `stage_name` を `current_stage` に入れる（`:249`）。
- 同 mapper `:66` の `debug_info.using_agrr_progress` は `!progress_records.is_empty()`。この `debug_info` は HTTP 応答に含まれない（`crates/agrr-server/src/field_cultivation_climate.rs:118-128` の `success_json` は `field_cultivation / farm / crop_requirements / weather_data / gdd_data / stages` のみ）。クライアントは agrr 由来か手計算由来か判別できない。
- 手計算と agrr の数値がどれだけ乖離するかは未確認（agrr 側のアルゴリズムを読んでいない）。乖離の有無に関わらず、規約上は「別アルゴリズムで成功表示しない」に該当する。
- 既存テスト: 改訂 2 の時点では agrr 経路のみを検証し、手計算経路のテストは無かった。master の #1337・#1338・#1342 で、手計算経路・基準値・期間外・null 累積の特性化テストが追加された（`crates/agrr-domain/test/field_cultivation/mappers_field_cultivation_climate_data_mapper_test.rs` の `build_output_*` は現在 8 件: `:7`、`:49`、`:92`、手計算 `:148`・`:196`、基準値 `:231`、期間外 `:271`、null `:304`）。`debug_info["using_agrr_progress"]` を表明する箇所は、このファイルに 5 か所（`:45`、`:186`、`:261`、`:299`、`:333`）、interactor テストに 3 か所（`...interactor_test.rs:631`、`:662`、`:689`）ある。各テストと本計画の関係は 6.0。
- progress が非空でも、期間 `[start_date, completion_date]` に入る record が 0 件だと `filtered_records` が空になり、`gdd_data` が空のまま成功する（`build_daily_gdd` `:190-202` で期間フィルタ、`:227-252` で構築）。手計算ほど悪くないが、失敗を隠す成功形である。
- 作物要件側にも代替値がある。`to_context_snapshot` は最小 `order` の stage に温度要件が無いとき `base_temperature` を `10.0` にする（`field_cultivation_climate_context_snapshot_mapper.rs:18`）。この値は応答の `crop_requirements.base_temperature`（mapper `:55`）に出る。また `climate_crop_agrr_requirement_from_entity`（`climate_crop_agrr_requirement_mapper.rs`）は温度・熱要件が揃わない stage を `continue` で捨て（`:9-16`）、全 stage が捨てられると `stage_requirements: []` のまま agrr に渡す（`:47-49`）。同 mapper には `max_temperature` `50.0`（`:29`）、`revenue_per_area` `5000.0`（`:37`）、`variety` `"general"`（`:42`）、`area_per_unit` `0.25`（`:43`）の既定値もある。これらが progress の結果に影響するかは未確認（agrr 本体を読んでいない）。

**A-4 出力ポート・HTTP・フロント**

- 出力ポート `FieldCultivationClimateDataOutputPort` は `present` / `on_error(Error)` の 2 メソッドのみ（`crates/agrr-domain/src/field_cultivation/ports/field_cultivation_climate_data_output_port.rs:4-7`）。`Error` は `message` だけを持つ（`crates/agrr-domain/src/shared/dtos/error.rs`）。impl は 2 つ: `ClimatePresenter`（`field_cultivation_climate.rs:47-54`）と `CaptureClimatePresenter`（`crates/agrr-server/src/work_record_climate_snapshot.rs:34-40`。`on_error` は空実装 `:39`）。
- 既存の失敗経路: interactor は前提条件不足・作物不在・気象なしを `handle_domain_error` → `on_error`（`:107-109, :171-181, :185-196, :202-208`）で通知する。progress 失敗にはこの経路が使われていない。
- HTTP 層は `on_error` のメッセージ文字列から `status_for_message`（`field_cultivation_climate.rs:102-115`）で状態コードを推定する。domain 側は `PassthroughTranslator`（`crates/agrr-server/src/adapters.rs:39-44`、キー文字列をそのまま返す）を注入している（`field_cultivation_climate.rs:192`）ため、メッセージは `api.errors.*` のキー文字列になる。コード読解上、`"api.errors.no_cultivation_period"` は判定語（`栽培期間` / `cultivation period` / `start_date`）に一致せず 500、`"Forbidden"`（`:104`）も 500 になる（実行未検証）。新しい失敗種別を追加する場合、この文字列推定に頼ると意図した状態コードにならない。たとえばキー `api.errors.climate_progress_unavailable` は判定語のどれにも一致せず 500 になる。
- `interactor.call` が `Err` を返した場合は 500 + `e.to_string()`（`field_cultivation_climate.rs:227-232`）。
- 本エンドポイント（`/api/v1/plans/field_cultivations/{id}/climate_data`, `/api/v1/public_plans/field_cultivations/{id}/climate_data`）は `docs/api/openapi.yaml` に記載がない（`grep` で該当なしを確認）。R4 契約テスト（`crates/agrr-r4-contract/tests/`）にも `climate_data` の参照がない。interactor のテストは、改訂 2 の時点では存在しなかった（`include!` が無かった）が、master の #1339〜#1344 で追加された。`field_cultivation_climate_data_interactor.rs:642-649` が `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_climate_data_interactor_test.rs` を `include!` で取り込み、16 件のテストが `cargo test -p agrr-domain`（`run-test-rust-domain.sh`）の対象になっている（6.0）。
- フロント: `FieldClimateApiGateway` は `GET .../climate_data` を叩く（`frontend/src/app/adapters/plans/field-climate-api.gateway.ts:12-35`）。型 `FieldCultivationClimateData` に `success: boolean` はあるが手計算由来かを示す項目はない（`frontend/src/app/domain/plans/field-cultivation-climate-data.ts:54-62`）。チャート画面は `control.error` を表示できる（`frontend/src/app/components/plans/plan-field-climate.component.ts:118-119`）が、`LoadFieldClimateUseCase` の error ハンドラは `err.error.error ?? err.error.errors ?? err.message` を読む（`frontend/src/app/usecase/plans/field-climate/load-field-climate.usecase.ts:86-93`）。サーバは `{"success": false, "message": ...}` を返す（`field_cultivation_climate.rs:236-239`）ので `message` は読まれず、Angular の `HttpErrorResponse.message` が表示に回る（読解上。実画面は未確認）。これは 07 の領域で、07 の確定契約（`errors` 1 系統、旧キー `message` は削除）では F1 でこの usecase が `apiErrorMessage` に置き換わる。05 が新設する失敗本文は `errors` を持つため、現行のコードでも、F1 後でも表示に使われる（0.4）。
- 他のフロント利用者 3 件（`preview-work-record-climate.usecase.ts:76`、`preview-work-row-mini-climate.usecase.ts:72`、`load-work-day-list.usecase.ts:75`）は HTTP エラーを空状態・`null` に丸める。
- **GET の 502/503 はフロントが再試行する。** `ApiService.get` は `retryOnBackendWarmup` を適用し（`frontend/src/app/services/api.service.ts:44-56`。`post` / `patch` / `put` には無い）、`isBackendWarmupHttpError` が真なら 2000 ms 間隔で最大 30 回再試行する（`frontend/src/app/core/backend-warmup/retry-backend-warmup.ts:5-6, 17-24`）。`isBackendWarmupHttpError` は 502・503・0 を真にする（`backend-warmup.ts:108-121`、`:117`）。ただし本文に `error` キーがあり、503 かつ daemon 系メッセージでないコードなら `isEntryScheduleWeatherHttpError`（`:84-106`）が真になり再試行されない。つまり 502/503 の応答は本文の `error` キーの有無で再試行の有無が変わる（読解上。実ブラウザは未確認）。07 の確定契約では `error` キーが廃止されるため、F1 後はこの判定が本文の `errors[0]` に移る（07 §3.7.1、§8 R22）。05 の新しい 503 の扱いは 0.4 で決めた。

**A-5 作業記録スナップショット（改訂: 手計算値の永続化は現構成では到達しない）**

- 作業記録の作成・更新は `WorkRecordClimateSnapshotGateway::lookup` を使い、`gdd_at_actual` と `weather_snapshot` を保存する（`work_record_create_interactor.rs:154-165`、`work_record_update_interactor.rs:79-91`）。実装 `WorkRecordClimateSnapshotService::lookup` は同じ `FieldCultivationClimateDataInteractor` を使う（`work_record_climate_snapshot.rs:96-150`）。
- `lookup` は interactor を `user_id = None`・`user_lookup = None` で構築する（`work_record_climate_snapshot.rs:122-126`）。interactor は user が無いと `assert_public_field_cultivation_plan_access`（`plan_field_cultivation_authorization.rs:19-27`）を呼び、plan が public でなければ `PolicyPermissionDenied` を返す。interactor はこれを `handle_policy_denied` → `on_error("Forbidden")` にする（interactor `:147-155, :103-105`）。
- 作業記録は private plan にしか作れない。作成・更新は `private_plan_access::access_allowed`（`work_record_create_interactor.rs:70`、`work_record_update_interactor.rs:65`）を通り、private でない plan は拒否される（`private_cultivation_plan_access_policy.rs:13-15`）。`plan_type_public` は plan_type 文字列 `"public"` との一致（`climate_source_gateway.rs:279`）。
- `CaptureClimatePresenter::on_error` は空実装（`:39`）なので `presenter.output` は `None` のまま、`lookup` は `WorkRecordClimateSnapshot::empty()` を返す（`:150`）。
- 読解上の結論: 現構成では、作業記録の climate 取得は private plan で常に認可拒否 → 空スナップショットになり、progress 失敗時の手計算値は `gdd_at_actual` に到達しない。R4 契約が `UPDATE work_records SET gdd_at_actual = 110.0` で値を直接入れている（`crates/agrr-r4-contract/tests/contracts.rs:151` ほか計 5 箇所）ことは、この読解と矛盾しないが証拠ではない。**未確認: 実行での再現。**
- したがって改訂前の「手計算値が永続化され得る」は潜在リスクである。認可の欠陥が直ると顕在化する。同時に次の 2 点は現時点でも厳格方針の違反である。
- (i) `lookup` は Forbidden・前提条件不足・作物不在を含むすべての `on_error` を空スナップショットの成功で隠す。
- (ii) 更新は `lookup` の `Err` を `.ok()` で握りつぶし（`work_record_update_interactor.rs:82-84`）、`climate` が `None` になる。gateway は `climate` が `Some` のときだけ `gdd_at_actual` を書く（`work_record_gateway.rs:300-311`）ので、`actual_date` を変えても旧日付の `gdd_at_actual` が残る。作成側は `if let Ok`（`work_record_create_interactor.rs:158-164`）で無視する。この現状は master の #1340 のテストが固定している（作成: `interactors_work_record_create_interactor_test.rs` の `create_omits_climate_fields_when_snapshot_lookup_fails`（`:369`）、更新: `interactors_work_record_update_interactor_test.rs` の `update_omits_climate_refresh_when_snapshot_lookup_fails`（`:387`））。どちらの失敗スタブも型を持たない文字列の `Err`（`"climate_progress_unavailable"`）を返す。ゲートウェイ側では、#1341 のテスト `work_record_gateway_update_preserves_gdd_when_climate_refresh_omitted`（`crates/agrr-adapters-sqlite/src/work_record/work_record_gateway_integration_test.rs`）が、`climate` が `None` の更新で `actual_date` が変わっても `gdd_at_actual` と `weather_snapshot` が更新されないことを固定している（`work_record_gateway.rs:300-311` の読解と一致）。

**A-6 手計算 GDD 関数の利用状況（リポジトリ全体を grep）**

- `calculate_gdd_manually`: 定義 `field_cultivation_climate_data_mapper.rs:265`（private `fn`）と呼び出し `:188` の 1 箇所のみ。他の crate・テスト・フロント・ドキュメント（本書を除く）に関数名の参照は無い（`rg` で確認）。ただし手計算の振る舞いは `build_output` 経由の既存テストが固定している（6.0）。
- `using_agrr_progress`: 定義 `:66` と既存テストの表明 8 か所（mapper テスト 5、interactor テスト 3。2.A-3）のみ。HTTP 応答・フロントへは出ない（A-3）。
- 削除すると `build_daily_gdd` の引数 `weather_data_records` と `base_temp` は、手計算でしか使われていないため不要になる（`:172-181` の引数、`:188` が唯一の使用箇所。読解）。

**A の未確認事項**

- crop に有効な stage が 0 件のとき（`climate_crop_agrr_requirement_from_entity` は温度・熱要件を欠く stage を `continue` で捨てる、`climate_crop_agrr_requirement_mapper.rs:9-16`）、agrr が `Err` を返すか空 progress を返すか。厳格方針では作物要件の事前検査で失敗にするため（3.A-3）、この挙動に依存しない。
- 同 interactor 内の `load_plan_prediction_payload(...).unwrap_or(json!({}))`（`:361-362`）は、キャッシュが無く観測が非空のとき観測のみの payload を作り（`merge_cached_with_observed` `field_cultivation_climate_weather_payload_mapper.rs:79-114`）、`valid_weather_payload` は `data` キーの存在だけを見る（`:127-131`）ため検証を通り得る。厳格方針では 06 が違反として扱う対象（10 章）。progress の入力そのものに関わるため、06 の修正と順序を合わせる。master の #1340〜#1341 のテストは、このうち「期間が未来で観測マージを飛ばす（`skip_merge`、`:368-370`）場合」だけを固定している。`{}` が `assert_valid_weather_payload`（`:332`、`:503-515`）で `WeatherPayloadInvalidError` になり、`call` が `Err` を返す（`returns_weather_payload_invalid_error_when_cached_plan_prediction_is_absent`: `...interactor_test.rs:869`、`..._cached_payload_has_no_data`: `:940`、store 読取失敗の伝播 `propagates_error_when_plan_prediction_store_read_fails`: `:798`）。観測マージが走る場合（栽培期間の開始が過去）に検証を通り得る点は、テストが無く、読解のみである。

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
- interactor の logger は本番配線で `Some(&NoopLogger)`（`entry_schedule.rs:332`）。`log_error` は何も出力しないため、「DB エラーと要件未定義をログで区別する」は配線を `StderrLogger` に変えない限り成立しない。

**B-4 同一ファイル内の隣接する握りつぶし（B の範囲外だが同型。厳格方針では違反確定）**

- `entry_schedule.rs:292-299` `load_crop_entity_for_optimize`: `find_by_id` の失敗を `CropEntity::new(crop.id(), crop.name(), None, true)` に置換（`cultivation_method` が `None` になる。テスト `:994-1007` が現状の挙動を固定している）。
- `entry_schedule.rs:167-171` `SqliteOptimizeCropGateway::entry_schedule_ordered_stage_rows`: 温度要件の読取り失敗を `.ok().flatten()` で `None` にする。ただし同関数は `Result` を返し、呼び出し側は `Err` を `failed_result("crop_stage_load_failed")` にする（`entry_schedule_optimize_interactor.rs:152-157`）ので、`?` で伝播すれば既存の fail-closed 形に乗る。
- どちらも 06 に詳細設計がある（06 §3.1 の項目 1 と、`entry_schedule_ordered_stage_rows` を扱う節）。厳格方針では「疑い」でなく違反確定であり、放置しない。05 の B と同じ PR で扱うかは 06 の着手順に合わせる（10 章）。

**B-5 cultivation_plan 側の同型パターン**

- 作物要件の欠落を握りつぶさない実装が既にある: 最適化入力 `cultivation_plan_optimization_sqlite_gateway.rs:81-82`（`build_crop_agrr_requirement(...)?.ok_or_else(|| format!("crop {crop_id} has no growth stages"))?`）、タスクスケジュール生成 `task_schedule_generation_read_gateway.rs:210-216`（`ok_or_else(|| "crop #{crop_id} has no agrr requirement")`）。これらが B の修正方針の先例。
- adjust 側 `plan_allocation_adjust_read_gateway.rs:399-414` は `None` を `requirement: None` として渡す。ただし成長ステージ 0 件は `plan_allocation_adjust_interactor.rs:131-138` で `crop_missing_growth_stages` の明示エラーになる。残る隙間（stage はあるが温度・熱要件が揃わず `Ok(None)` になるケース）は未確認。06 で扱う。
- `cultivation_plan` 内で `unwrap_or(json!({}))` 型の要件握りつぶしは grep で見つからなかった（B のみ）。

## 3. あるべき振る舞い（fail-closed 規約・厳格適用）

### 3.A climate_data

**A-1 progress が `Err`（確定 D1）**

- 成功応答を返さない。`gdd_data` を別アルゴリズムで埋めない。空 progress にも落とさない。
- 失敗は typed な失敗出力（`FieldCultivationClimateFailure`。3.A-6）で出力ポートに通知し、HTTP は 200 にしない（LAYER-RULES R5）。
- gateway の `Err` は文字列でなく型で分類する。domain に `ClimateProgressGatewayError`（`DaemonUnavailable` / `ExecutionFailed(message)`）を置き、adapter が構築して返す。先例: `TaskScheduleProgressAgrrGateway` は adapter が domain の型（`TaskScheduleSyncError`）を構築して返す（`task_schedule_progress_gateway.rs:41-43, 56-61`）。`DaemonUnavailable` の Display は `"daemon_unavailable"` のまま保つ（2.A-2）。
- 型に該当しない `Err` は分類を推測せず、そのまま `Err` として伝播する（現状の 500 経路 `field_cultivation_climate.rs:227-232`）。文字列一致で `DaemonUnavailable` とみなすことはしない。

**A-2 progress が成功でも使えない結果（確定 D2）**

判定は domain の policy（純関数）で行い、interactor が `calculate_progress` の直後に呼ぶ。adapter の `normalize_progress_result` は task schedule 側と共有のため変えない（8 章 2）。次のいずれかに該当したら `ProgressResultInvalid` とする。

- **F1:** `progress_records` が配列でない、または 0 件。
- **F2:** いずれかの record が、ISO 日付として解釈できる `date` と、数値の `cumulative_gdd` を持たない（`unwrap_or(0.0)` の代替を残さない。2.A-2、2.A-3）。
- **F3:** `[start_date, completion_date]` に入る record が 1 件も無い。

**正当な 0 件があり得るかの確認（コード・文書の読解。実行は未確認）:**

- agrr の `progress` は weather-file に実在する日次だけを返す（`.cursor/skills/cultivation-climate-chart-investigation/SKILL.md:59`、`references/code-paths.md:51`）。
- 本実装は期間で切っていない weather payload をそのまま渡す（`build_climate_output` `:309-310`）。
- したがって期間内の record が 0 件になるのは、weather payload に `start_date` 以降の行が無い（天候カバレッジ欠落）か、agrr が入力を処理していない場合に限られる。
- 「栽培開始が未来」は、プランの予測気象が未来日を含むことで埋まる前提のドメイン設計である（`plan_predicted_weather_present`、`:320-329`）。予測が届かないなら失敗が正しい。
- `start_date` / `completion_date` は `climate_precondition_failure_message`（`:222-235`）で必須になっており、欠落は progress に到達する前に失敗する。
- 結論: 現行ドメインに正当な 0 件は存在しない。0 件は常に失敗とする。
- 原因は入力側と agrr 側で区別する。`build_climate_output` は期間内の天候行数を `extract_weather_records`（`:302-306`）で既に得ている。失敗メッセージとログに「期間内の天候行数」を含め、0 なら天候カバレッジ欠落、1 以上なら agrr が空を返した、と読めるようにする。失敗種別は同じ `ProgressResultInvalid`。
- 未確認: agrr 本体（リポジトリ外）が期間内の天候が十分にあるときに 0 件を返す条件、予測の地平が常に `completion_date` に届くか。実 daemon がある環境では既存の live テスト（`field_cultivation_climate_gateway_test.rs:58-81`）と同じ入力形で観測できる。

**A-3 作物要件の不完全（確定 D3）**

- climate_data は、progress を呼ぶ前に作物要件を検査し、不完全なら `CropRequirementIncomplete` で失敗する。空の `stage_requirements` を agrr に渡さない。
- 「不完全」の定義:
  - 温度要件と熱要件の両方を持つ stage が 0 件。
  - `base_temperature` の基準である最小 `order` の stage に温度要件が無い。
- `to_context_snapshot` の `unwrap_or(10.0)`（`field_cultivation_climate_context_snapshot_mapper.rs:18`）は撤廃する。`Result` を返す形に変え、panic を増やさない。既存の `expect("precondition ensures start_date")`（`:24`）の前例には倣わない。
- 検査は `call` の前提条件検査（`:175-181`）と同じ位置、`to_context_snapshot`（`:198`）の前に置く。天候取得・agrr 呼び出しより前なので、天候や daemon に依存せず決定的に再現できる（R4 でも固定できる。6 章）。
- 一部の stage だけが捨てられる場合（有効 stage が 1 件以上残る）の扱いは、`build_crop_agrr_requirement`（`agrr_requirement.rs:80-82, :99-101`）が同じ動きで、cultivation_plan 側の共有挙動でもある。本書では変えず、06 に送る（8 章 6）。
- 要件 JSON の既定値（`max_temperature` `50.0` ほか。2.A-3）が progress に影響するかは未確認。06 で扱う。

**A-4 手計算関数の削除（確定 D4）**

- `calculate_gdd_manually` と `using_agrr_progress` を削除する。他の利用者が無いことは 2.A-6 で確認済み（`project-necessary-code-only`）。
- `build_daily_gdd` の空 progress 分岐を消す。引数 `weather_data_records` と `base_temp` も不要になるので削除する。
- `using_agrr_progress` を表明する既存の 8 か所（2.A-3）は、キーの削除に合わせて表明そのものを削除する。キー不在の表明は足さない（足すと 9 章の `grep` 0 件と矛盾し、`project-necessary-code-only` にも反する）。
- 手計算経路を固定している既存テスト（mapper テストの `:148`・`:196`、interactor テストの `:637`・`:668`・`:1183`）は、6.0 の処置に従って反転・削除する。
- F2 の検査は interactor 側の policy に置くため、mapper の `unwrap_or(0.0)`（`:219`、`:232`、`:238`）は到達不能な代替値になる。撤去する（5.A 手順 7）。

**A-5 作業記録（確定 D5 と推奨、確認 U2・U3）**

現状を 2.A-5 に記した。確定・推奨は次のとおり。

- **確定:** progress 不可の失敗は `lookup` から typed エラー（`WorkRecordClimateSnapshotUnavailableError` が `FieldCultivationClimateFailure` を保持する形を推奨）として返し、create / update はこれを握りつぶさない。`.ok()`（`work_record_update_interactor.rs:82-84`）と `if let Ok`（`work_record_create_interactor.rs:158-164`）は撤廃する。`CaptureClimatePresenter` は `on_failure` を受けて失敗を保持し、`lookup` が返す。
- **確定:** 手計算値は A-4 の削除でそもそも生成されない。古い `gdd_at_actual` が残る更新の穴（2.A-5 (ii)）は、エラー伝播で塞がる。
- **推奨（U2）:** create / update 自体を失敗にする。理由は次のとおり。
  - `gdd_at_actual` を null にして 201/200 を返すと、応答は成功形なのに値が欠けており、クライアントは欠落を判別できない。厳格方針（0.1）は「空値による成功形」を許さない。
  - create は `lookup` が `gateway.create` より前（`work_record_create_interactor.rs:74-77`）、update は `gateway.update` より前（`work_record_update_interactor.rs:77-96`）に呼ばれるので、失敗を返しても何も永続化されない。
  - 出力ポートに `on_climate_snapshot_unavailable(failure)` を追加する。
  - HTTP は `work_records.rs` に新しい outcome（例: `MutationOutcome::SnapshotUnavailable`）を足し、状態コードは A-6 と同じ写像を使う。
  - 本文は 0.4 の形（`errors` 配列 + `error_code`）。既存の `unauthorized` / `not_found` / `internal_error`（`work_records.rs:172-184, :193-198`）は文字列配列で整合するが、`record_invalid`（`:186-191`）は `errors` が項目別 map（07 の区分 D）なので、新しい outcome の手本にしない。
- **UX 影響（U2）:** agrr 障害中は作業記録を保存できない。フロントは 422 以外を `apiErrorI18nKey` に渡す（`create-work-record.usecase.ts:30-38`）。503 の POST は `isBackendWarmupHttpError` が真になるため warmup 系メッセージが表示される（`api-error-i18n-key.ts:51-53`）。POST は再試行されない（`api.service.ts:62-70`）。
- **代替案（推奨しない）:** null で保存を続行する。作業記録本体が主データで GDD が派生値であるという整理は可能だが、成功形の空値になるため 0.1 と両立しない。採用するなら、欠落を示す応答項目（スキーマ変更）が要る。
- **未解決（U3）:** `lookup` が Forbidden・前提条件不足・作物不在を含むすべての `on_error` を空スナップショットで隠す点（2.A-5 (i)）は、認可コンテキスト（`user_id = None`）の欠陥と一体である。`on_error` を握りつぶさず失敗にすると、現状は private plan のすべての作業記録作成が失敗する。欠陥を先に直す必要があり、直すと挙動が変わる（`gdd_at_actual` の記録が始まり、agrr 呼び出しが増える）。この扱いは U3 で確認する。それまでは typed な progress 失敗の伝播のみを行う。

**A-6 typed な失敗種別と HTTP ステータス（確定 D6、コード値は U1）**

- domain に失敗 DTO を置く。先例: `CropBlueprintRegenerateFailureReason` / `CropBlueprintRegenerateFailure { reason, message }`（`crates/agrr-domain/src/crop/dtos/crop_blueprint_regenerate_failure.rs`）。
  - `FieldCultivationClimateFailureReason`: `ProgressDaemonUnavailable` / `ProgressExecutionFailed` / `ProgressResultInvalid` / `CropRequirementIncomplete`。
  - `FieldCultivationClimateFailure { reason, message }`。
- 出力ポートに `on_failure(&mut self, failure: FieldCultivationClimateFailure)` を 1 つ追加する（種別ごとにメソッドを増やさない）。
- server は `reason` の**網羅的な `match`** で状態コードと `error_key` を決める。新しい種別を足すと、写像の未更新がコンパイルエラーになる。先例: `regenerate_failure_response`（`crates/agrr-server/src/masters_crop_task_schedule_blueprints.rs:429-441`。`MissingAgrrRequirement` は 422、`AiUnavailable` は 503）。
- 新規の失敗は `on_error` と `status_for_message` を経由しない。既存の `on_error` 分岐（作物不在・前提条件・Forbidden・データなし）の状態コードは本書では変えない。その typed 化は 10 authorization-consistency の Forbidden の扱いと一体で行う（10 章）。
- 本文は 07 の確定契約（0.4）に合わせる: `{"success": false, "errors": ["<reason 由来の i18n キー>"], "error_code": "<reason の snake_case>"}`。`message`・`error`・`error_key` は付けない。server は 07 の S0 で導入される `api_error.rs` を使い、`api_error_with_code(status, key, code, Legacy::None)` に `success: false` を足して作る（署名は 07 §3.6 の案で、導入前は存在しない）。キー名・`error_code` の値と、503 の再試行の扱い（`errors[0]` に `daemon_unavailable` を含める）は 0.4 に表にした。

| 失敗種別 | 推奨 | 理由 | 代替 |
|----------|------|------|------|
| `ProgressDaemonUnavailable` | 503 | 一過性の依存先不在。`entry_schedule.rs:220,229,391` の 503 先例と揃う。フロントの GET は 502/503 を backend warmup として再試行する（2.A-4）ため、daemon 起動待ちの意図と合う。07 の F1 後も再試行を保つため、`errors[0]` に `daemon_unavailable` を含める（0.4） | 502 |
| `ProgressExecutionFailed` | 500 | agrr の実行失敗は決定的な場合があり、502/503 だとフロントの GET が最大 30 回（約 60 秒）再試行して待たせる | 502（再試行される。上流失敗の意味には合う） |
| `ProgressResultInvalid` | 500 | 天候カバレッジ欠落・agrr の不正結果は再試行で直らない。502 だと同じ再試行に入る | 502 / 422 |
| `CropRequirementIncomplete` | 422 | 作物マスタのデータ欠落でユーザー起因の是正が要る。先例: `MissingAgrrRequirement` の 422 | 500 |

### 3.B entry schedule

- 作物要件が取得できない・未定義の場合、agrr を呼ばず `eligible: false` + `reason_parts.error_key = "crop_requirement_error"` を返す（確定 D7。既存キー・既存文言・既存 `failed_result` を再利用）。HTTP 状態は変えない（`eligible:false` は 200 の本文で表現する既存契約）。
- DB エラー（`Err`）と要件未定義（`Ok(None)`）は port 上で区別する必要はない（どちらも `crop_requirement_error`）。区別はログで行うが、現状の `NoopLogger` 配線（2.B-3）では出力されないため、`OptimizeRunner` の interactor には `StderrLogger` を渡す（5.B）。
- B-4 の隣接 2 箇所は 06 の設計に従って同時に是正する（確定 D8）。

## 4. 影響範囲

### 4.A climate_data

| 区分 | 対象 |
|------|------|
| domain interactor | `field_cultivation_climate_data_interactor.rs`（`build_climate_output` を `Result` 化、`call` に失敗の分岐、作物要件の事前検査） |
| domain error | `crates/agrr-domain/src/field_cultivation/errors/climate_errors.rs` に `ClimateProgressGatewayError`（既存 `WeatherPayloadInvalidError` と同じファイル） |
| domain dto | `crates/agrr-domain/src/field_cultivation/dtos/`（新規 `FieldCultivationClimateFailure` / `Reason`） |
| domain policy | `crates/agrr-domain/src/field_cultivation/policies/`（新規: progress 結果の検査 F1〜F3、作物要件の完全性。既存の `climate_crop_view_allowed` などと同じ置き場） |
| domain port | `FieldCultivationClimateDataOutputPort` に `on_failure(FieldCultivationClimateFailure)` を追加。impl 2 件（`field_cultivation_climate.rs:47`、`work_record_climate_snapshot.rs:34`）の更新が必須 |
| domain mapper | `field_cultivation_climate_data_mapper.rs`（`calculate_gdd_manually`・`using_agrr_progress` の削除、`build_daily_gdd` の分岐整理と不要引数の削除）、`field_cultivation_climate_context_snapshot_mapper.rs:18`（`10.0` 撤廃、`Result` 化） |
| adapter | `crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:64-73`（trait 実装が `ClimateProgressGatewayError` を返す）。`normalize_progress_result` は変更しない。既存テスト `field_cultivation_climate_gateway_test.rs:8-32, 36-60`（`:51` の downcast）の更新が必要。task schedule 側は Display 文字列 `"daemon_unavailable"` を保てば影響なし（`task_schedule_progress_gateway.rs:59-60`） |
| HTTP | `field_cultivation_climate.rs`（`ClimateOutcome` に失敗種別、`reason` の網羅的な写像、`NoopLogger` → `StderrLogger`）。`status_for_message` は既存分岐のためだけに残す。本文は 07 の `api_error.rs`（S0）経由で `errors` + `error_code`（0.4）。新設ファイル `api_error.rs` は 07 の変更セットに属する |
| 作業記録 domain | `WorkRecordCreateOutputPort` / `WorkRecordUpdateOutputPort` に `on_climate_snapshot_unavailable` を追加（`crates/agrr-domain/src/work_record/ports/mod.rs:20-28, 40-49`）。impl は本番 2 件（`work_records.rs:88, :124`）とテストの Spy 2 件（`interactors_work_record_create_interactor_test.rs:46-52`、`interactors_work_record_update_interactor_test.rs:45-50`）。失敗スタブ `FailingClimateSnapshot`（文字列の `Err`）は #1340 で両テストに追加済み（create `:179-189`、update `:147-157`）。`build_persist_attrs` は `RecordInvalidError` だけを返す形（`:82-86`）なので、エラー型を広げる必要がある |
| 作業記録 server | `work_record_climate_snapshot.rs`（`CaptureClimatePresenter` が失敗を保持、`lookup` が typed エラーを返す、`NoopLogger` → `StderrLogger`）、`work_records.rs`（新 outcome と HTTP 写像） |
| 呼び出し元 | HTTP ハンドラ（`run_climate_data`）と作業記録スナップショット（`work_record_climate_snapshot.rs`）の 2 件のみ（`FieldCultivationClimateDataInteractor` の grep 結果） |
| テスト | 既存 interactor テスト（16 件、#1339〜#1344）の更新（反転 3 件、書換 1 件。スタブ `SpyClimateOutput` への `on_failure` 追加を含む）と、そこへの A-R3・A-R6〜R8 の追加、新規 policy テスト、既存 mapper テストの反転・削除（mapper 3 ファイル）、既存作業記録 interactor テストの反転（2 件）、adapter テスト、R4 契約。既存テストごとの処置は 6.0 |
| フロント | 表示可能な失敗状態は既存（`plan-field-climate.component.ts:118`）。新しい失敗本文は `errors` を持つため、現行の読み取り（`load-field-climate.usecase.ts:86-93`）でも 07 の F1 後でも表示に使われ、変更は不要（0.4）。i18n を足す場合は `plans-field-climate-keys.spec.ts` の必須キー一覧の更新が必要 |
| 翻訳キー | 新規 4 キー（`api.errors.climate_progress_daemon_unavailable` / `api.errors.climate_progress_execution_failed` / `api.errors.climate_progress_result_invalid` / `api.errors.climate_crop_requirement_incomplete`。0.4）を `config/locales/{ja,en,in}.yml` と `frontend/src/assets/i18n/{ja,en,in}.json` に追加（`api.errors.no_weather_data` と同じ置き場: `ja.yml:112`、`ja.json:1623`）。`us.yml` の要否は未確認（`us.yml:53` に `no_weather_data` はある）。キー文字列は `errors[0]` にそのまま入り、フロントが `translate` で表示する。フロント個別文言を出す場合のみ `plans.field_climate.*` に追加 |
| ドキュメント | `docs/api/openapi.yaml` に当該 endpoint なし（08 で扱う） |

### 4.B entry schedule

| 区分 | 対象 |
|------|------|
| domain port | `crop_agrr_requirement_builder_port.rs:9` の戻り値を `Result<Value, Box<dyn Error + Send + Sync>>` に変更 |
| domain interactor | `entry_schedule_optimize_interactor.rs:82-83`（`match` で `Err` → `log_error` + `failed_result("crop_requirement_error")`） |
| impl | `entry_schedule.rs:132-142`（唯一の本番 impl。`Ok(None)` を `Err` に変換） |
| server 配線 | `entry_schedule.rs:332`（`Some(&NoopLogger)` → `StderrLogger`） |
| テスト impl | `StubBuilder`（`...optimize_interactor_test.rs:58-68`）を `Ok(...)` に更新（既存テストの本文は不変） |
| 呼び出し元 | interactor `:82` の 1 箇所のみ |
| B-4 | 06 の設計に従う（10 章） |
| フロント・翻訳 | 変更なし（キー・文言が既存） |
| ドキュメント | `entry_schedule/crops` は `docs/api/openapi.yaml` に記載なし（08） |

## 5. 対応方針（層ごとの変更）

### 5.A climate_data

1. **domain error**: `ClimateProgressGatewayError`（`DaemonUnavailable` / `ExecutionFailed(String)`。Display は `DaemonUnavailable` が `"daemon_unavailable"`）を `climate_errors.rs` に追加する。
2. **domain dto**: `FieldCultivationClimateFailureReason` と `FieldCultivationClimateFailure { reason, message }`。
3. **adapter**: `FieldCultivationClimateAgrrGateway` の trait 実装で、`AgrrDaemonError::NotRunning`（`is_daemon_not_running`）を `DaemonUnavailable` に、それ以外を `ExecutionFailed(err.to_string())` にする。`calculate_progress_result`（inherent メソッド）は `AgrrDaemonError` を返したままにする。
4. **policy**:
   - progress 結果の検査（F1〜F3、3.A-2）。`Result<(), FieldCultivationClimateFailure>` を返す純関数。
   - 作物要件の完全性の検査（3.A-3）。
5. **interactor**:
   - `call` の前提条件検査の直後、`to_context_snapshot` の前に作物要件の検査を置く（`CropRequirementIncomplete`）。
   - `build_climate_output` を `Result<FieldCultivationClimateDataOutput, Box<dyn Error + Send + Sync>>` にする。
   - `calculate_progress` の `Err` は `ClimateProgressGatewayError` に downcast して `ProgressDaemonUnavailable` / `ProgressExecutionFailed` にし、原因を logger に出す。型に該当しない `Err` は分類せずそのまま返す。
   - `Ok` の結果は policy で検査し、不合格は `ProgressResultInvalid`（メッセージとログに期間内の天候行数を含める）。
   - `assemble_climate_data` / `assemble_climate_data_from_fallback` で `?` 伝播する。
   - `call` の `match`（`:200-211`）に、失敗 DTO を運ぶエラーの downcast 分岐を足し、`self.output_port.on_failure(failure)` して `return Ok(())` する。`RecordNotFoundError` の downcast 分岐（`:127, :164`）と同型で、既存コードとの一貫性を優先する（R5 の "rescue-as-control-flow" に厳密に従うなら enum 戻り値化が代替案。既存 interactor と揃えるため本計画では採らない）。
6. **output port**: `on_failure(&mut self, failure: FieldCultivationClimateFailure)` を追加。`on_error` の文字列推定に頼らず状態コードを確定できる。
7. **mapper**: `calculate_gdd_manually`・`using_agrr_progress` を削除し、`build_daily_gdd` の空分岐と不要引数を消す。`to_context_snapshot` の `unwrap_or(10.0)` を撤廃して `Result` にする。`unwrap_or(0.0)`（`:219`、`:232`、`:238`）は、F2 の検査が先に弾くため到達不能になる。`build_output` が `pub` で生の `Value` を受ける点を踏まえ、`Result` 化するか、検証済みの型を受ける形にするかは実装時に決める（どちらでも、`cumulative_gdd` が無い record を 0.0 として成功させない）。
8. **server（climate_data）**:
   - `ClimatePresenter` が `on_failure` を保持し、`reason` の網羅的な `match` で状態コード・`errors[0]` のキー・`error_code` を決める（U1 の回答と 0.4 の表に従う）。本文は 07 の `api_error.rs` で組み立てる（S0 の後）。
   - `NoopLogger` を `StderrLogger` に変える（`adapters.rs:19`）。
9. **作業記録**（U2 の回答に従う）:
   - `CaptureClimatePresenter::on_failure` が失敗を保持し、`lookup` は `Err(WorkRecordClimateSnapshotUnavailableError)` を返す。`presenter.output` が無い他のケースは U3 の回答まで現状維持。
   - create / update の `.ok()` / `if let Ok` を撤廃し、typed エラーは `on_climate_snapshot_unavailable`、それ以外の `Err` はそのまま伝播する。
   - `work_records.rs` に outcome と HTTP 写像を追加する。
10. **翻訳**: 3 ロケール分のキー追加（4.A）。
11. **フロント**: 本件では必須変更なし（既存の失敗状態表示が働き、新しい本文の `errors` は現行の読み取りでも 07 の F1 後でも表示に使われる。0.4）。3 利用者の空状態への丸め（2.A-4）は U6 の受容事項。

### 5.B entry schedule

案 B-1（推奨・最小）: port を `Result` にする。

1. port: `fn build_from(&self, crop_source: &dyn CropAgrrRequirementSource) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>`。
2. interactor `:82`: `Err(e)` → `self.log_error(...)` → `return self.failed_result("crop_requirement_error")`。`optimize_period` を呼ばない。
3. impl `AgrrCropBuilder`: `build_crop_agrr_requirement(...)?.ok_or_else(|| format!("crop #{} has no agrr requirement", ...).into())`（`task_schedule_generation_read_gateway.rs:214-215` と同型）。
4. `StubBuilder`（`:58-68`）と、#1341 で追加された `EmptyCropRequirementBuilder`（`:1034-1039`）を新シグネチャに更新する。後者を使う既存テスト `forwards_empty_crop_requirement_when_builder_swallows_missing_requirement`（`:1042`）は B-R1 に反転する（6.0）。
5. `OptimizeRunner::call`（`entry_schedule.rs:332`）の logger を `StderrLogger` にする。

案 B-2: port と `CropAgrrRequirementSource` を廃止し、interactor が既存の `crop::gateways::CropAgrrRequirementGateway::build_for_crop_id -> Result<Option<Value>, _>`（`crates/agrr-domain/src/crop/gateways/crop_agrr_requirement_gateway.rs:4`、impl `crates/agrr-adapters-sqlite/src/crop/crop_agrr_requirement_gateway.rs:16-23`）を直接使う。`AgrrCropBuilder`（server private）が不要になり、`None` を型で表現できる。波及は `EntryScheduleOptimizeCrop` の supertrait 削除（`:20`）、`CropWrap` / `TestCrop` の空 impl 削除、interactor のジェネリクス変更（`B` → 既存 gateway 型）、`EntryScheduleOptimizeInteractor::new` の全呼び出し（`entry_schedule.rs:325-334` とテスト 23 箇所（#1341 で 1 箇所増えた）、`interactors_entry_schedule_optimize_interactor_test.rs` の `EntryScheduleOptimizeInteractor::new(` 呼び出し）で大きい。設計上は綺麗だが、port を `Result` にする波及の範囲を超えるため、採否は U5 で確認する。

B-4 の隣接 2 箇所は 06 の設計に従う（案・テストは 06 §3.1 ほか）。06 側で `load_crop_entity_for_optimize` を削除する案 A を採ると、05 の B 変更とは独立に進められる。

## 6. TDD 計画（RED の失敗テスト）

実行は `test-common` のスクリプトのみ。出力は `./tmp/{UUID}.log` にリダイレクトして grep する（`AGENTS.md`）。RED を確認してから GREEN に進む（`tdd-on-edit`）。

注意 1: `agrr-server` の inline テスト（`entry_schedule.rs` 末尾、`field_cultivation_climate.rs` 等）は `run-test-rust-domain.sh`（`cargo test -p agrr-domain` と `agrr-migrate`）にも CI（`.github/workflows/rust-domain-test.yml:51-58`。`agrr-domain` / `agrr-migrate` / `agrr-adapters-sqlite -- '_gateway_test'`）にも含まれない。ゲートされないテストは RED/GREEN の根拠にしない。server 層の振る舞いは R4 契約で固定する。なお、改訂 2 の時点で「ゲート外」としていた climate の interactor は、#1339 の `include!` 以降は `agrr-domain` のテストとして `run-test-rust-domain.sh` でゲートされる。#1341 の sqlite 統合テスト `work_record_gateway_update_preserves_gdd_when_climate_refresh_omitted` は、テスト名・モジュール名（`work_record_gateway_integration_test`）が部分文字列 `_gateway_test` を含まないため、CI のフィルタ `'_gateway_test'` に掛からない（名前の読解。`cargo test` での確認は未実施）。

注意 2: `run-test-rust-domain.sh` は引数を `cargo test -p agrr-domain "$@"` にそのまま渡す（スクリプト `:22`）。`-p agrr-adapters-agrr` を追加指定して adapter のテストを同じスクリプトから流せる可能性があるが、未実行で、CI ではゲートされない。adapter テストの RED/GREEN をこの経路で取るかは実装着手時に確認する（8 章 8）。

### 6.0 既存の特性化テスト（master #1337〜#1344）との関係

master には「現状のフォールバック挙動を固定する」特性化テストが入っている。#1337・#1338・#1339 は改訂 2 の後、#1340〜#1344 は今回の依頼範囲で、いずれも `docs/spec-defects/05` / `06` を根拠にしている。これらは現状の成功形（手計算・握りつぶし・代替値）を固定しているため、厳格方針（0.1）では「RED を新設する」のではなく、**既存テストを反転・削除する**のが TDD の入口になる。以下の表は全件をテスト本体まで読んで作った（実行はしていない）。

処置の凡例: **維持**=そのまま GREEN。**反転**=表明を厳格方針の期待値に書き換えて RED にし、実装で GREEN にする。**書換**=given を変えて別の目的（06 の経路固定など）を保つ。**削除**=固定対象のコードを消すコミットで同時に削除する（削除は RED にならない）。

略称: I=`interactors_field_cultivation_climate_data_interactor_test.rs`、M=`mappers_field_cultivation_climate_data_mapper_test.rs`、C=`mappers_field_cultivation_climate_context_snapshot_mapper_test.rs`、Q=`mappers_climate_crop_agrr_requirement_mapper_test.rs`（以上 `crates/agrr-domain/test/field_cultivation/`）、WC / WU=`crates/agrr-domain/test/work_record/interactors_work_record_{create,update}_interactor_test.rs`、E=`crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_optimize_interactor_test.rs`。

**A（climate_data）**

| テスト（PR） | 現状固定している内容 | 厳格方針での処置 | 対応する RED（6.A） |
|--------------|----------------------|------------------|---------------------|
| I `presents_agrr_progress_when_gateway_succeeds`（`:605`、#1339） | 正常な progress は agrr の値（`gdd`=5.0）を `present` する | **維持**。`:631` の `using_agrr_progress` 表明だけを削除する | A-R5 を兼ねる（新規テスト不要） |
| I `presents_manual_gdd_when_progress_gateway_returns_empty_records`（`:637`、#1341） | `{"progress_records": []}` でも手計算 GDD（2 件）を `success` として `present`（`using_agrr_progress == false`） | **反転**。F1 により `on_failure(ProgressResultInvalid)`、`present` 0 回 | A-R4 |
| I `presents_manual_gdd_when_progress_gateway_fails`（`:668`、#1339） | progress が `Err` でも手計算 GDD を `present`。失敗スタブ `FailingProgressGateway`（`:183`）は文字列 `Err("daemon_unavailable")` | **反転**。この文字列 `Err` は型に該当しないため、`call` が `Err` を返し、`present` も `on_failure` も呼ばれない（分類しない。A-R3）。型付き `Err` の `on_failure(ProgressDaemonUnavailable / ExecutionFailed)` は新規テストで固定する（A-R1・A-R2） | A-R3。A-R1・A-R2 は新規 |
| I `presents_climate_via_observed_fallback_when_plan_has_no_cached_metadata`（`:1183`、#1344） | キャッシュ無しの観測のみフォールバックで、空 progress でも `gdd_data` が非空（手計算）で `success` | **書換**。given の progress を期間内の record 付きにして、06 項目 3 が扱う気象フォールバック経路の固定を保つ。空 progress のままだと F1 で失敗に変わり、目的がずれる | （05 の RED 対象外。06 の経路固定を維持） |
| I `invokes_plan_prediction_when_plan_has_no_cached_metadata`（`:1119`、#1344） | キャッシュ無しで予測が `None` のとき `Field cultivation climate data not found`。progress は呼ばれない | **維持**。`SpyClimateOutput`（`:63-74`）への `on_failure` 追加によるコンパイル更新のみ | – |
| I `on_error_when_weather_location_is_missing`（`:518`）・`..._cultivation_period_is_missing`（`:548`）・`forbidden_for_anonymous_access_to_private_plan`（`:578`）・`on_error_when_plan_crop_is_unlinked`（`:738`）・`..._climate_source_snapshot_is_missing`（`:768`）・`..._plan_access_snapshot_is_missing`（`:1013`） | 既存の `on_error` 経路（前提条件、認可、作物不在、not found）。メッセージはキー文字列（`PassthroughTranslator` 相当の `StubTranslator`） | **維持**。05 は既存の `on_error` 分岐を変えない（3.A-6）。`Forbidden` の typed 化は 10 | – |
| I `propagates_error_when_plan_prediction_store_read_fails`（`:798`）・`returns_weather_payload_invalid_error_when_cached_plan_prediction_is_absent`（`:869`）・`..._cached_payload_has_no_data`（`:940`）（#1343・#1341・#1340） | store 読取失敗は `call` の `Err`。キャッシュ無し／`data` 無しの payload は `WeatherPayloadInvalidError`。いずれも `present` / `on_error` 0 回（既に fail-closed。未来の栽培期間のみ） | **維持**。2.A の「未確認」の一部（`:361-362`）を固定している。観測マージが走る場合は未固定で、06 の項目 3 で扱う | – |
| I `apply_display_range_intersects_gantt_bounds_with_cultivation_period`（`:696`）・`ignores_invalid_display_range_strings_and_returns_full_series`（`:1085`） | 表示範囲の絞り込み（正常な progress で動く） | **維持**。progress は期間内の record を持つので F1〜F3 に抵触しない | – |
| M `build_output_assembles_climate_dto`（`:7`）・`..._truncates_gdd_at_final_cumulative_requirement`（`:49`）・`..._aligns_weather_data_span_with_truncated_gdd_data`（`:92`） | agrr 経路の組み立て・打ち切り・天候データ範囲の整合 | **維持**。`:45` の `using_agrr_progress` 表明だけを削除 | – |
| M `build_output_uses_manual_gdd_when_progress_records_are_empty`（`:148`、#1337） | 空 progress で手計算 GDD（`gdd`=5.0 / 2.0、`current_stage` は null）。`using_agrr_progress == false` | **反転**。`build_output` に空 progress が渡っても手計算値を作らず `gdd_data` は空。実運用では policy が先に弾くため到達しないが、`build_output` は `pub` で、別アルゴリズムで埋めない契約を単体で固定する | A-R10 |
| M `build_output_manual_gdd_derives_mean_from_max_and_min_when_mean_is_absent`（`:196`、#1337） | 手計算の平均気温の導出（max/min から平均） | **削除**（`calculate_gdd_manually` の削除と同じコミット） | – |
| M `build_output_subtracts_baseline_cumulative_gdd_from_day_before_start_date`（`:231`、#1338） | 開始日の前日の累積を基準値として引く（agrr 経路） | **維持**。`:261` の表明だけを削除。開始日の record が progress に無いと基準値が `0.0` になる（`:223-225`）点は未固定で、U4 の領域 | – |
| M `build_output_leaves_gdd_empty_when_progress_dates_are_outside_cultivation_period`（`:271`、#1338） | 期間外の record だけだと `gdd_data` が空のまま成功形 | **削除**。F3 により interactor が `ProgressResultInvalid` にするため、成功形の空は到達不能になる。F3 は A-R9（policy）と A-R4 の隣の interactor テストで固定する | A-R9（F3） |
| M `build_output_treats_null_cumulative_gdd_as_zero_in_agrr_progress_path`（`:304`、#1342） | `cumulative_gdd: null` を `0.0` として扱う代替値 | **削除**（mapper の `unwrap_or(0.0)` の撤去と同じコミット）。F2 は A-R9（policy）で固定する | A-R9（F2） |
| C `defaults_base_temperature_to_ten_when_lowest_order_stage_has_no_temperature`（`:92`、#1338） | 最小 `order` の stage に温度要件が無いと `base_temperature = 10.0`、`stages` は空 | **反転**。`to_context_snapshot` が `Err`（`10.0` を返さない） | A-R11 |
| C `maps_crop_stages_into_context`（`:16`）・`accumulates_cumulative_gdd_required_across_ordered_stages`（`:120`、#1338） | stage の写像と累積要求 GDD | **維持** | – |
| Q `builds_rails_crop_requirement_shape`（`:16`） | agrr 用要件 JSON の形 | **維持** | – |
| Q `omits_stages_missing_temperature_or_thermal_requirements`（`:57`、#1338） | 温度・熱要件が揃わない stage を捨てる（有効 1 件は残る） | **維持**。一部 stage の脱落は 05 では変えない（3.A-3、8 章 6 → 06）。全 stage が脱落する場合は、A-R6 の事前検査が先に弾くので、この mapper には届かない | – |
| Q `applies_default_crop_fields_when_optional_attributes_are_absent`（`:100`、#1338） | 既定値（`variety` `general`、`area_per_unit` 0.25、`revenue_per_area` 5000.0、`max_temperature` 50.0） | **維持**。要件 JSON の既定値は 05 では変えない（8 章 6 → 06） | – |

**作業記録**

| テスト（PR） | 現状固定している内容 | 厳格方針での処置 | 対応する RED（6.A） |
|--------------|----------------------|------------------|---------------------|
| WC `create_omits_climate_fields_when_snapshot_lookup_fails`（`:369`、#1340） | `lookup` が文字列 `Err` でも作成が成功し、`gdd_at_actual` と `weather_snapshot` が `None` で永続化される（`events == ["success"]`） | **反転**。given の文字列 `Err` は型に該当しないため、`call_rescuing` が `Err` を返し、`gateway.create` は呼ばれない（W-R3）。型付き失敗の `on_climate_snapshot_unavailable` は新規テストで固定する（W-R1） | W-R3（create 側）。W-R1 は新規 |
| WU `update_omits_climate_refresh_when_snapshot_lookup_fails`（`:387`、#1340） | `lookup` が文字列 `Err` でも更新が成功し、ゲートウェイへ `climate = None` が渡る（`RecordingUpdateGateway`: `:159`） | **反転**。given の文字列 `Err` は型に該当しないため `call_rescuing` が `Err` を返し、`gateway.update` は呼ばれない（スロットが `None` のまま。W-R3）。型付き失敗の通知は新規テストで固定する（W-R2） | W-R3（update 側）。W-R2 は新規 |
| WC `create_persists_climate_snapshot_when_field_cultivation_present`（`:430`） | 正常時に `gdd_at_actual` と `weather_snapshot` を保存 | **維持** | W-R5 |
| sqlite `work_record_gateway_update_preserves_gdd_when_climate_refresh_omitted`（`crates/agrr-adapters-sqlite/src/work_record/work_record_gateway_integration_test.rs`、#1341） | `climate = None` の更新は、`actual_date` を変えても `gdd_at_actual`（120.0）・`weather_snapshot` を更新しない | **維持（given は要調整）**。ゲートウェイの「`None` なら更新しない」契約は、日付不変の更新（W-R4）で必要。ただし日付変更を含む given は、旧日付の GDD が残る現状（2.A-5 (ii)）を固定しているように読めるため、日付不変の更新に直すか、interactor 側が日付変更時に `None` を渡さないことを W-R2 で固定したうえで意図をテスト名に残す。実装時に決める | W-R4 |

**B（entry_schedule）**

| テスト（PR） | 現状固定している内容 | 厳格方針での処置 | 対応する RED（6.B） |
|--------------|----------------------|------------------|---------------------|
| E `forwards_empty_crop_requirement_when_builder_swallows_missing_requirement`（`:1042`、#1341。`EmptyCropRequirementBuilder`: `:1034-1039`） | builder が `{}` を返すと、`optimize_period` に `{}` がそのまま渡る（`captured_requirement == Some({})`）。最適化ゲートウェイのスタブが `Err(crop_requirement_error)` を返すので、`eligible == false` はスタブ由来 | **反転**。builder が `Err` のとき `optimize_period` は呼ばれない（`captured_requirement == None`）。スタブの最適化結果を成功系にして、`eligible == false` と `error_key == "crop_requirement_error"` が builder 失敗のみから出ることを示す | B-R1。7 章 B の「現行で `{}` が渡ることを観測する一時テスト」は、このテストが既に担っている |
| E `maps_non_domain_optimize_errors_to_crop_requirement_error`（`:954`）・`maps_entry_schedule_optimization_error_to_failed_result`（`:1003`）・`does_not_fall_back_to_temperature_windows_when_optimize_fails`（`:311`）・`scales_crop_requirement_before_optimize_period`（`:241`） | 最適化失敗の既存マッピングと要件のスケーリング | **維持** | B-R2 |

**06 の対象で、05 の RED に影響しないもの（参考）**

- #1337 `WindowService` の `optimal_max` のみの窓（`interactors_entry_schedule_window_service_test.rs`）: 06 項目 7。
- #1342・#1343 `FieldsAllocation` の代替値、`CultivationPlanInitializeInteractor` の空作物・store 読取（`calculators_fields_allocation_test.rs`、`interactors_cultivation_plan_initialize_interactor_test.rs`）: 06 項目 5。
- #1344 `plan_still_optimizing` の DB エラー握りつぶし（`crates/agrr-server/src/optimization_chain_phase.rs:301`。server inline でゲート外）: 06 項目 4。
- #1341・#1343・#1344 `AgrrCropsConfigCalculator` の `requirement: None` / 非オブジェクト要件（`calculators_agrr_crops_config_calculator_test.rs`）: 06 の H1。2.B-5 の「stage はあるが要件が `None`」の隙間に隣接する。
- これらの固定内容を 06 の判定・TDD 計画へどう反映するかは 06 側で扱う（06 は本書の改訂 3 と並行して更新中で、本書では 06 の記述との整合を確認していない）。本書が引き受けるのは、上の A・B の表に載せた 05 の対象だけである。

**新規 RED が不要になるもの / なお新規が必要なもの**

- 不要: A-R5（既存 `:605`）、B 手順の「観測用の一時テスト」、`interactors_field_cultivation_climate_data_interactor_test.rs` の新規作成と `include!` の追加（改訂 2 の A-R1 の前提。既に存在する）、手計算経路の特性化（既に固定済みで、反転・削除すれば足りる）。
- なお新規が必要: A-R6・A-R7（作物要件の事前検査。interactor テストの `run_interactor`（`:456-515`）は `sample_crop()`（`:352`）固定なので、作物を引数にする）、A-R8（記録する logger。既存の `NoopLogger`（`:45`）は何も記録しない）、A-R9（policy）、A-R3 用の `Err` を返す `run_interactor` の変種（既存は `expect("interactor call")` で `Err` を許さない）、A-R12〜R14、W-R1・W-R2 の型付き失敗スタブ（既存の `FailingClimateSnapshot` は文字列 `Err`）、W-R4、B-R3（既存の `FakeLogger`（`E:135`）は何も記録しない）、B-R4。

### 6.A climate_data

domain のテストは `crates/agrr-domain/test/field_cultivation/` に置き、実行は `run-test-rust-domain.sh <フィルタ>`。interactor のフィルタは `field_cultivation_climate_data_interactor`（モジュール名 `interactors_field_cultivation_climate_data_interactor_test_inline`）。表の「既存」は 6.0 の対応を指す。

| # | 種別 | パス案 | given / when / then | 現状の期待 |
|---|------|--------|--------------------|-----------|
| A-R1 | domain interactor | 既存 `interactors_field_cultivation_climate_data_interactor_test.rs`（`include!` 済み。新規ファイルは不要）。`SpyClimateOutput`（`:63-74`）に `on_failure` を足し、型付きの `Err` を返す progress gateway を足す。A-R1・A-R2 は新規テスト（既存 `presents_manual_gdd_when_progress_gateway_fails`（`:668`）は文字列 `Err` を使うので A-R3 に反転する。6.0） | given: 権限・source・crop・気象 payload が正常で、progress gateway が `ClimateProgressGatewayError::DaemonUnavailable` を返す。then: `on_failure(ProgressDaemonUnavailable)` が 1 回、`present` 0 回、`on_error` 0 回、`call` は `Ok(())` | 現状は `present` が呼ばれ RED（`on_failure` 未定義のため先にコンパイルエラー。新規 API の追加ではコンパイルエラーの RED は正当） |
| A-R2 | domain interactor | 同上 | given: progress gateway が `ExecutionFailed`。then: `on_failure(ProgressExecutionFailed)` | 同上 |
| A-R3 | domain interactor | 同上。既存の `FailingProgressGateway`（`:183`。文字列 `Err("daemon_unavailable")`）と既存テスト `:668` の given をそのまま使い、then を反転する。`run_interactor`（`:456-515`）は `call` の `Err` を `expect` するため、`Result` を返す変種を足す | given: 型に該当しない `Err`（文字列だけのエラー）。then: `call` は `Err`、`on_failure` 0 回、`present` 0 回（文字列 `"daemon_unavailable"` でも分類しない） | 現状は `present` が呼ばれ RED（`:668` の given と同じ） |
| A-R4 | domain interactor | 同上。既存 `presents_manual_gdd_when_progress_gateway_returns_empty_records`（`:637`）を反転する | given: progress gateway が `Ok({"progress_records": []})`。then: `on_failure(ProgressResultInvalid)`、メッセージに期間内の天候行数を含む | 現状は手計算 GDD を `present` して RED |
| A-R5 | domain interactor | **新規不要**。既存 `presents_agrr_progress_when_gateway_succeeds`（`:605`）が担う | given: 正常な `progress_records`。then: `present` の `gdd_data` が agrr の値（`gdd`=5.0）で、失敗の通知は無い。`using_agrr_progress` の表明（`:631`）だけ削除し、`on_failure` が呼ばれないことは A-R1 の Spy で担保する | 現状も GREEN（特性化。退行防止） |
| A-R6 | domain interactor | 同上。`run_interactor` は作物が `sample_crop()`（`:352`）固定なので、作物を引数にする | given: 有効 stage 0 件の作物（全 stage で温度・熱要件のどちらかが無い）。then: `on_failure(CropRequirementIncomplete)`、progress gateway の呼び出しが 0 回（呼ばれたら失敗するスタブ） | 現状は空要件のまま agrr を呼び RED |
| A-R7 | domain interactor | 同上 | given: 最小 `order` の stage に温度要件が無く、他の stage は有効。then: `on_failure(CropRequirementIncomplete)`（`10.0` の代替値を使わない） | 現状は `base_temperature = 10.0` で成功し RED |
| A-R8 | domain interactor | 同上。記録する logger を新設する（既存 `NoopLogger`: `:45` は何も記録しない） | given: 上記いずれかの失敗。then: logger に原因文字列が出る | 現状は未出力で RED |
| A-R9 | domain policy | 新規 `policies_field_cultivation_climate_progress_policy_test.rs` | F1（配列でない、0 件）、F2（`date` 不正、`cumulative_gdd` 欠落・非数値）、F3（全 record が期間外）が失敗。正常は成功。境界（期間の開始日・終了日ちょうどの record、開始日前の基準 record を含む正常ケース）も含める。F2・F3 は、削除する mapper の特性化テスト（`M:304` の null、`M:271` の期間外。6.0）の代わりに固定する | 新規 API のため RED（コンパイルエラー） |
| A-R10 | domain mapper | 既存 `mappers_field_cultivation_climate_data_mapper_test.rs` の `build_output_uses_manual_gdd_when_progress_records_are_empty`（`:148`）を反転する | given: `progress_result = {"progress_records": []}` と非空の weather。when: `build_output`。then: `gdd_data` が空で、手計算値が入らない。`using_agrr_progress` の表明（`:45`、`:186`、`:261`、`:299`、`:333`）は削除する（キー不在の表明は足さない） | 現状は手計算値が入り RED（表明失敗。コンパイルは通る） |
| A-R11 | domain mapper | 既存 `mappers_field_cultivation_climate_context_snapshot_mapper_test.rs` の `defaults_base_temperature_to_ten_when_lowest_order_stage_has_no_temperature`（`:92`）を反転する | given: 最小 `order` の stage に温度要件なし。when: `to_context_snapshot`。then: `Err`（`10.0` を返さない） | 現状は `Ok`（`10.0`）で RED（`Result` 化によるコンパイルエラーを含む） |
| A-R12 | adapter | 既存 `crates/agrr-adapters-agrr/tests/field_cultivation_climate_gateway_test.rs`（`:8-32, 36-60`） | trait 実装が、daemon 未起動で `ClimateProgressGatewayError::DaemonUnavailable`（Display `"daemon_unavailable"`）、それ以外の失敗で `ExecutionFailed` を返す。`:51` の downcast 先を更新する | 現状は adapter の `DaemonUnavailableError` のため RED。実行経路は注意 2 |
| A-R13 | R4 契約 | `crates/agrr-r4-contract/tests/contracts.rs`（`support.rs` に climate 用 seed が必要な可能性。`field_cultivations` の seed は `support.rs:457, 933, 1192` に既存だが、期間・`weather_location`・作物 stage まで揃うかは未確認） | given: 有効 stage 0 件の作物を持つ field cultivation。when: climate_data を取得。then: 422、`success: false`、`errors == ["api.errors.climate_crop_requirement_incomplete"]`、`error_code == "crop_requirement_incomplete"`、`error` と `message` が存在しない（07 の `assert_error_envelope`（S-T0）が導入済みならそれを使う）。天候・agrr に依存せず決定的に再現できる（3.A-3 の検査位置による） | 現状は 200 か別の失敗（agrr 経路は環境依存）で RED。観測手順: `run-rust-contract-tests.sh` を実行して確認 |
| A-R14 | R4 契約 | 同上 | given: agrr daemon が到達不能（binary 不在の環境）で天候が揃う climate_data。then: 503、`errors[0]` が `daemon_unavailable` を含むキー（`api.errors.climate_progress_daemon_unavailable`）、`error_code == "progress_daemon_unavailable"`、`error` と `message` が存在しない。binary 有りの環境では daemon 停止を作れないためスキップ（`agrr_regeneration_contract_available()` 分岐の先例、`contracts.rs` の entry_schedule 契約 `:4766-4810`） | 現状は 200 で RED（daemon 不在環境のみ。決定的な RED を作れるかは未確認） |

作業記録（U2 の推奨案が前提。回答が変わればテストも変わる）:

| # | 種別 | パス案 | given / when / then | 現状の期待 |
|---|------|--------|--------------------|-----------|
| W-R1 | domain interactor | 既存 `interactors_work_record_create_interactor_test.rs`。型付き `Err(WorkRecordClimateSnapshotUnavailableError)` を返すスタブを追加する（既存 `FailingClimateSnapshot`（`:179-189`）は文字列 `Err` で、W-R3 に使う） | given: `field_cultivation_id` を持つ入力で `lookup` が typed エラー。then: `on_climate_snapshot_unavailable` が 1 回、`gateway.create` 0 回、`on_success` 0 回 | 現状は `if let Ok` で握りつぶして作成が成功し RED（Spy の新メソッドで先にコンパイルエラー） |
| W-R2 | domain interactor | 既存 `interactors_work_record_update_interactor_test.rs` に、型付きスタブを使う新規テストを足す（既存の失敗スタブ `FailingClimateSnapshot`: `:147-157` は文字列 `Err` で、W-R3 の update 側）。`RecordingUpdateGateway`（`:159`）の `climate_at_update` が `None` のままなら `update` は呼ばれていない | given: `actual_date` を変える更新で `lookup` が typed エラー。then: `on_climate_snapshot_unavailable`、`gateway.update` 0 回 | 現状は `.ok()` で `None` になり更新が成功し RED |
| W-R3 | domain interactor | create・update の両方。既存の `create_omits_climate_fields_when_snapshot_lookup_fails`（create `:369`）と `update_omits_climate_refresh_when_snapshot_lookup_fails`（update `:387`）を反転する（given の文字列 `Err` はそのまま） | given: `lookup` が typed でない `Err`（既存の `"climate_progress_unavailable"`）。then: `call_rescuing` が `Err` を返す（握りつぶさない）。`gateway.create` / `update` は呼ばれない | 現状は握りつぶして成功し RED |
| W-R4 | domain interactor | update の新規テスト（`RecordingUpdateGateway` と、呼び出し回数を数える `lookup` を使う） | given: `actual_date` 不変の更新。then: `lookup` が呼ばれず従来どおり成功し、ゲートウェイへ `climate = None` が渡る（特性化。sqlite の `work_record_gateway_update_preserves_gdd_when_climate_refresh_omitted` の given を日付不変に直す場合の対応先） | 現状も GREEN |
| W-R5 | domain interactor | 既存 `create_persists_climate_snapshot_when_field_cultivation_present`（create テスト `:430`） | 正常時に `gdd_at_actual` と `weather_snapshot` を保存することが GREEN のまま | 特性化 |

`CaptureClimatePresenter` と `work_records.rs` の写像は server inline テストになりゲートされない。認可の欠陥（2.A-5）が残る間、R4 で作業記録の失敗を再現することはできない（`lookup` が常に空になるため）。U3 で欠陥を直す場合に R4 の契約を追加する（未確認: 既存 R4 の作業記録 seed で daemon 不在を再現できるか）。

### 6.B entry schedule

| # | 種別 | パス案 | given / when / then | 現状の期待 | スクリプト |
|---|------|--------|--------------------|-----------|-----------|
| B-R1 | domain | `crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_optimize_interactor_test.rs` の既存テスト `forwards_empty_crop_requirement_when_builder_swallows_missing_requirement`（`:1042`、#1341）を反転する | given: builder が `Err("no requirement")`（新シグネチャ。`EmptyCropRequirementBuilder`: `:1034-1039` を差し替える）で、最適化ゲートウェイのスタブは成功系（`Err` を返さない）。when: `call`。then: `eligible == false`、`error_key == "crop_requirement_error"`、`StubOptimizationGateway.captured_requirement` が `None`（`optimize_period` 未呼び出し）。スタブが失敗系のままだと `eligible == false` がスタブ由来になり、builder の失敗を示せない | 現状はシグネチャ不一致のコンパイルエラーで RED。握りつぶしの証拠（builder が `{}` を返すと `optimize_period` に `{}` が渡る）は、このテストの現行の表明（`captured_requirement == Some({})`）が既に固定している | `run-test-rust-domain.sh entry_schedule_optimize` |
| B-R2 | domain | 同上 | given: builder `Ok(要件)`。then: 既存 `scales_crop_requirement_before_optimize_period`（`:241`）が GREEN のまま | 特性化（退行防止） | 同上 |
| B-R3 | domain | 同上。記録する logger を新設する（既存 `FakeLogger`: `:135` は何も記録しない） | given: builder `Err`。then: `logger.error` が 1 回 | 現状は未出力で RED | 同上 |
| B-R4 | R4 契約 | `contracts.rs`（`get_entry_schedule_crop_show_*` の隣）+ `support.rs` の `seed_entry_schedule_contract_assets`（`:758` 付近）に「stage はあるが `thermal_requirements` 行なし」の作物を作る seed を追加 | given: 参照農場・参照作物（要件欠落）・agrr 有効（`run-rust-contract-tests.sh:278-281` は binary があるときのみ `USE_AGRR_DAEMON=true`）。when: `GET /api/v1/public_plans/entry_schedule/crops/{id}?farm_id=`。then: 200、`crop.eligible == false`、`crop.reason_parts.error_key == "crop_requirement_error"` | 現状の観測値は未確認（agrr が `{}` を拒否すれば `execution_failed`、受理すれば別結果）。RED 実行で観測する。binary 不在環境では `disabled` になるためスキップ | `scripts/run-rust-contract-tests.sh` |

## 7. 実装ステップ

A と B は独立した変更セットにできる（ファイル・型が重ならない）。それぞれ `RED → GREEN → REFACTOR`（`tdd-on-edit`）。テストだけの赤いコミットは CI を壊すため、RED は作業ツリーで確認し、コミットは GREEN 到達単位でまとめる。

**A（この順）**

1. 0.3 の U1〜U4、U6 の回答を得る。
2. A-R1〜R11 を書き、`run-test-rust-domain.sh` で RED を確認。
3. domain: error 型、失敗 DTO、policy、output port メソッド、interactor、mapper の最小変更で GREEN。両 impl のスタブ更新。→ コミット 1「domain: climate の progress・作物要件の失敗を fail-closed にする」。
4. adapter: gateway の型付き失敗（A-R12）。→ コミット 2。実行経路は 6 章の注意 2 に従う。
5. server（climate_data）: `ClimatePresenter`、状態コード、`StderrLogger`、翻訳キー（yml + json）。A-R13・R14 を追加して `run-rust-contract-tests.sh`。→ コミット 3。
6. 作業記録（U2 の回答後）: W-R1〜R5 を書いて RED → domain の port・interactor を変更して GREEN → server の `CaptureClimatePresenter` と HTTP 写像。→ コミット 4。U3 の欠陥修正を含める場合は別コミットにする。
7. REFACTOR: 手計算の残骸（`calculate_gdd_manually`、`using_agrr_progress`）と `unwrap_or(10.0)` が残っていないことを確認（`grep` で 0 件）。
8. フロントの原因別メッセージは 07 の後続（本件では変更しない）。変更する場合は `run-test-frontend.sh`。
9. Docker 検証: `crates/agrr-server/**`・`crates/agrr-domain/**`・`crates/agrr-adapters-*/**` を変更したので、検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必要（`docker compose restart agrr-server` では不十分）。
10. 完了後 `test-slow-detection`。個別 GREEN → 全体（`run-test-rust-domain.sh` 引数なし + `run-rust-contract-tests.sh`）の順。

**B（この順）**

1. 0.3 の U5 の回答を得る。
2. B-R1・B-R3 を追加（B-R1 の前に、現行で `{}` が `optimize_period` に渡ることを観測するテストを一時的に書いて記録する）。RED 確認。
3. port・interactor・`AgrrCropBuilder`・`StubBuilder`・logger 配線を変更して GREEN。→ コミット 1。
4. B-R4（seed 追加を含む）を追加して `run-rust-contract-tests.sh`。→ コミット 2。
5. `crates/agrr-server/**` と `crates/agrr-domain/**` を変更するため、Docker 検証前に `rebuild-restart.sh`。
6. B-4 の 2 箇所は 06 の実装ステップに従う（05 と 06 のどちらが先でも、同じ関数を二重に直さない）。

## 8. リスク・未確定事項

| # | 内容 | 状態 |
|---|------|------|
| 1 | agrr 本体（リポジトリ外）が、期間内の天候が十分にあるときに `progress_records` 0 件を返す条件。domain の F3 と予測地平の関係 | 未確認。3.A-2。本書は「0 件は常に失敗」で確定し、観測で覆るなら基準を見直す |
| 2 | `normalize_progress_result:33` が未知形を空に丸める点。domain の F1 で吸収できるが、原因が「未知形」か「0 件」かはログで区別できない。adapter を `Err` にするなら `progress_daemon_normalize.rs` のテスト更新と、task schedule 側（`task_schedule_progress_gateway.rs:59-61`）のエラーキーが `EMPTY_GDD_PROGRESS` から `AGRR_UNAVAILABLE` に変わる影響確認が必要 | 未確定（推奨: 変えない） |
| 3 | 作業記録: progress 不可時に作成・更新が失敗する UX 影響 | U2 |
| 4 | 既に永続化済みの手計算由来 `gdd_at_actual` を識別・是正する手段がない（`work_records` に由来フラグなし）。ただし 2.A-5 の読解が正しければ手計算値は保存されていない | 未確認（`production-primary-sqlite-query` スキルで、本番の `gdd_at_actual` が null か調査可能） |
| 5 | フロントの 3 利用者はエラーを空状態に丸めるため、503 化後は「空表示」になる（現状は手計算のグラフが出る）。GET の 502/503 は最大約 60 秒再試行される（2.A-4） | U1・U6 |
| 6 | 一部の stage だけが捨てられる作物要件（有効 stage が 1 件以上残る）と、要件 JSON の既定値（`50.0` ほか）の progress への影響。厳格方針でも、同じ挙動を共有する cultivation_plan 側と一体の判断が要る | 06 に送る。未確認 |
| 7 | 天候欠損で progress の先頭日が `start_date` より後のとき、積算が過小になる（`references/symptom-cause-tree.md` の A1 が「最多」の原因）。実データの積算で代替ではないため失敗にしない案（U4）だが、厳格に解すると失敗になり、頻度は未確認 | U4 |
| 8 | `agrr-server` inline テストと adapter テストが CI のゲート外。server 層の状態コード・presenter は R4 でしか固定できず、R4 は agrr binary の有無で分岐するため決定的な RED を作れない可能性。`reason` の網羅 `match` はコンパイルで担保されるが、値そのもの（503/500/422）の退行は `CropRequirementIncomplete` の R4（A-R13）以外ゲートされない | 未確認（A-R12〜R14、B-R4） |
| 9 | 案 B-2 の波及の大きさ（5.B） | U5 |
| 10 | B の RED が現状でどう振る舞うか（agrr が `{}` を受理するか） | 未確認。RED 実行で観測 |
| 11 | `status_for_message` が文字列推定である点（`"Forbidden"` が 500 になる読解）。A の新規種別は typed で回避するが、既存分岐は別課題 | 10 章の 07 / 10 |
| 12 | 作業記録の `lookup` の認可コンテキスト欠陥（`user_id = None`、2.A-5）。修正すると `gdd_at_actual` の記録開始・agrr 呼び出しの増加・R4 への影響という本番挙動の変化を伴う | U3 |
| 13 | 作業記録の `gdd_for_date`（`work_record_climate_snapshot_mapper.rs:22-39`）は、指定日に record が無いとき「その日以前の最後の値」を返す（テスト `:101-121` が仕様として固定）。GDD が要件で打ち切られた後の日付には打ち切り時の値が入る。厳格に解すると別日の値の流用に当たる可能性があるが、飽和値としての正当性の判断が要る | 本件では変更しない。06 に送る。未確認 |

## 9. 受け入れ条件

**A**

- [ ] `calculate_progress` が `Err` のとき、`climate_data` API は `success:true` を返さず、確定した状態コード（推奨: daemon 不在は 503、実行失敗は 500）と失敗種別由来の `error_key` を返す。gateway の失敗分類は型で行われ、文字列一致に依存しない。
- [ ] `progress_records` が F1〜F3 のいずれかに該当するとき（0 件・不正形・期間外）、同様に失敗する。
- [ ] 作物要件が不完全なとき（有効 stage 0 件、または最小 `order` の stage に温度要件なし）、agrr を呼ばず 422（U1 の回答に従う）で失敗する。`crop_requirements.base_temperature` に `10.0` の代替値が出ない。
- [ ] `calculate_gdd_manually`・`using_agrr_progress`・`unwrap_or(10.0)` がコードベースから消えている（`grep` で 0 件）。
- [ ] `FieldCultivationClimateDataInteractor` の interactor テストが存在し、A-R1〜R8 が GREEN。policy・mapper・adapter のテスト（A-R9〜R12）も GREEN。
- [ ] 新規の失敗が `on_error` と `status_for_message` を経由しない（`reason` の網羅 `match` で決まる）。
- [ ] 作業記録の作成・更新は、progress 不可のとき何も永続化せず明示的に失敗する（U2 の回答に従う）。手計算値・古い `gdd_at_actual` を保存する経路が無い。`.ok()` / `if let Ok` による `lookup` の握りつぶしが無い。W-R1〜R5 が GREEN。
- [ ] climate_data と作業記録スナップショットの logger が `NoopLogger` でなく、失敗の原因がログに出る。
- [ ] `run-test-rust-domain.sh`（全体）と `run-rust-contract-tests.sh` が GREEN。遅延検知（`test-slow-detection`）を実施済み。
- [ ] 新規翻訳キーが 3 ロケールに揃っている。

**B**

- [ ] 作物要件が取得できない・未定義のとき、`optimize_period` が呼ばれず `eligible:false` + `error_key = "crop_requirement_error"` になる（B-R1 GREEN）。
- [ ] `AgrrCropBuilder` に `.ok().flatten().unwrap_or(json!({}))` が残っていない。
- [ ] `OptimizeRunner` の interactor の logger が `NoopLogger` でなく、失敗の原因がログに出る（B-R3 GREEN）。
- [ ] 既存テスト（`does_not_fall_back_to_temperature_windows_when_optimize_fails` ほか）が GREEN のまま。
- [ ] `run-test-rust-domain.sh` と `run-rust-contract-tests.sh` が GREEN。
- [ ] Docker で確認する場合は `rebuild-restart.sh` 後に実施している。

## 10. 関連課題との依存

| 番号 | 関係 |
|------|------|
| 06 fail-closed-suspected | 同型の箇所を引き継ぐ。厳格方針（0.1）では「疑い」でなく違反として扱う。`field_cultivation_climate_data_interactor.rs:361-362`（`unwrap_or(json!({}))`。progress の入力に関わるため 05 の A と修正順を合わせる）、`entry_schedule.rs:167-171, :292-299`（B-4。06 に設計あり。D8）、`plan_allocation_adjust_read_gateway.rs:399-414`（要件 `None`）、`field_cultivation_climate.rs:89-92` と `work_record_climate_snapshot.rs:64-78`（`StoreBackedWeatherPredictionService` が store の `Err` を `.ok().flatten()` で潰す）、`adjust_weather_prediction.rs:118, :142`（`.ok().flatten()`）、`crates/agrr-domain/src/shared/ports/interaction_rule_agrr_format_builder_port.rs:9`（`build_from -> Value` の同形 port。失敗表現なし。実害は未確認）、一部 stage が捨てられる作物要件と要件 JSON の既定値（8 章 6）、`gdd_for_date` の別日値流用（8 章 13）、`weather_location_meta_from_source` の timezone 既定 `"Asia/Tokyo"`（`field_cultivation_climate_weather_payload_mapper.rs:148-151`）。本書では扱わない。なお 06 の §9 は「`docs/spec-defects/` には 01〜04 のみが存在」と書いており、05 が存在する現在は更新が必要（06 の同節）。 |
| 07 frontend-error-contract | `load-field-climate.usecase.ts:86-93` が `message` を読まない点、3 利用者がエラーを空状態に丸める点、`error_key` の受け方。本文の `error` キーの有無でフロントの warmup 再試行の分類が変わる点（`backend-warmup.ts:84-121`）。A の原因別メッセージ表示は 07 の契約決定後。作業記録の POST で 503 が warmup 系メッセージとして表示される点（`api-error-i18n-key.ts:51-53`）も 07 で扱う。 |
| 08 openapi-gaps | `climate_data` と `entry_schedule/crops` が `docs/api/openapi.yaml` に無い。作業記録 API の 503 応答も含め、A の 503 / 422 / `error_key` 応答は 08 で記載する。 |
| 10 authorization-consistency | `climate_data` の `Forbidden` が `status_for_message` で 500 になる読解（実行未検証）。既存 `on_error` 分岐の typed 化（認可エラーの状態コード統一）は 10 で扱う。作業記録の `lookup` の認可コンテキスト欠陥（`user_id = None`。2.A-5、U3）も 10 の候補。A の変更では既存分岐に触れない。 |
| 01 resource-limit-bypass / 02 contact-recaptcha / 03 api-key-scope-docs / 04 api-key-query-auth | 依存なし（対象コードが重ならない）。 |
| 09 stale-design-docs | `docs/migration/archive/` と `.cursor/skills/cultivation-climate-chart-investigation/references/code-paths.md`（`FieldCultivationClimateDataMapper.build_daily_gdd` の記述が手計算分岐に触れていない）を、A 完了後に更新する候補。 |
| 11 low-priority-misc | 依存なし。 |
