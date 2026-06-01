# 予測系調査 — 蓄積知見

調査で**再現・ログ・debug ファイルで確認したこと**だけを書く。推測は「未確認」と明記する。

新規追記は末尾に、テンプレート:

```markdown
### #N — 短いタイトル（YYYY-MM-DD）

- **症状**:
- **根拠**:
- **切り分け**:
- **対処**（あれば）:
- **関連**:
```

---

## クイック参照

| 症状 | まず見る場所 | よくある原因 |
|------|----------------|--------------|
| `predicting_weather` 失敗 | `rust.log`, `prediction_input_*` | predict 空出力・入力日付潰れ |
| `fetching_weather` 失敗 | `WEATHER_DATA_SOURCE`, agrr `weather` | noaa タイムアウト（インド） |
| `prediction_output_*` 無し | 同上 + 手動 `predict` | lightgbm が出力ファイルを書かない |
| 参照農場は表示 OK・新規農場のみ NG | DB 日付形式・取得ジョブ | 同上 |
| `initializing` のまま・chain enqueued のみ | 本番 DB phase + Job agrr CLI | ジョブチェーン未進行（agrr とは別） |
| 本番 Job で `Daemon is not running` | `run-production-agrr-cli.sh` | daemon start なしで weather 直叩き |

---

### #1 — India fixture 日付が prediction_input で 1 日に潰れる（2026-05-31）

- **症状**: 公開プラン（`region: in`）で `predicting_weather` 失敗。`tmp/debug/prediction_input_*` の 7,000+ 行がすべて同じ `time`（例: `2006-01-01`）。ログ: `weather prediction: daemon command failed: agrr daemon output file is empty`。
- **根拠**:
  - DB は正常: `weather_data.date` は `2000-01-01T00:00:00` 形式で 9,000+ 日・重複なし。
  - JP 参照は `2000-01-01`（T なし）で `prediction_input` の日付は連続。
  - `WeatherDataSqliteGateway::parse_date` が `[year]-[month]-[day]` のみ解釈し、失敗時 `unwrap_or(start_date)` でクエリ開始日に潰していた。
- **切り分け**: KNOWLEDGE スクリプトで `unique_dates == 1`；SQLite の `substr(date,1,20)` を JP / IN で比較。
- **対処**: `parse_date` で先頭 10 文字をパース（`crates/agrr-adapters-sqlite/src/weather_data/weather_data_gateway.rs`）。テスト: `weather_data_gateway_test::weather_data_for_period_parses_iso_datetime_date_column`。
- **関連**: `db/fixtures/india_reference_weather.json`, `agrr-migrate` base apply。

---

### #2 — lightgbm predict が exit 0 でも出力ファイル無し（2026-05-31）

- **症状**: `weather_prediction failed` + `agrr daemon output file is empty`。手動でも `bin/agrr_client predict ... --model lightgbm --output /tmp/out.json` → exit 0 だがファイル無し。
- **根拠**: 同一 `prediction_input` で `--model arima` は `/tmp/out.json` が生成される（2026-05-31、ローカル `lib/core/agrr`）。
- **切り分け**: 手動 predict で model を切替。`prediction_output_*` が 17:07 大阪成功分のみ存在するケースと一致。
- **対処（開発）**: `export AGRR_PREDICT_MODEL=arima` または `AGRR_USE_MOCK=true` を **agrr-server 起動時**に渡す。ドメイン既定は `lightgbm`（`weather_prediction_interactor.rs`）。
- **関連**: `PredictionDaemonGateway::effective_model`, `optimization_job_chain.rs` の hint 行。

---

### #3 — 気象 data source と開発経路の差（2026-05-31）

- **症状**: 「インドは NOAA では？」— 実行時ソースが経路で異なる。
- **根拠**:
  - `determine_data_source`: `jp` → `jma`；`region` nil → `nasa-power`；**`in` / `us` → `noaa`**（Rust/Ruby 同型）。
  - `WeatherDaemonGateway` / `weather_daemon_gateway.rs`: **`WEATHER_DATA_SOURCE` 環境変数が agrr-server プロセスにあれば上書き**。
  - `docker-compose.yml`: `WEATHER_DATA_SOURCE=nasa-power`。
  - `dev-rust-stack.sh`: 2026-05-31 以降デフォルト `nasa-power` を export（要再起動）。
  - 手動: デリー座標で `noaa` は 180s タイムアウト、`nasa-power` は数秒で JSON 取得（`--output` 使用）。
- **切り分け**: `/proc/<agrr-server-pid>/environ`；agrr `weather --help` の data-source 一覧。
- **対処**: インドのライブ取得は `nasa-power` 推奨。参照農場の履歴は fixture シードが主（ライブ取得不要な画面もある）。
- **関連**: `env.example`, `bin/fetch_india_reference_weather_data`（コメントは NASA、CLI は `noaa-ftp` — スクリプトと実装のズレに注意）。

---

### #4 — tmp/debug ファイルの意味（2026-05-31）

- **症状**: debug だけ見ても何が失敗か分からない。
- **根拠**: `agrr_daemon_debug_dump.rs` — `AGRR_ENV=production` では書かない。
- **切り分け**:
  - `prediction_input_*` … `predict` **直前**の学習データ（マージ後全体ではない）。
  - `prediction_output_*` / `prediction_transformed_*` … predict **成功時のみ**。
  - `progress_weather_*` / `progress_crop_*` … 最適化・調整の agrr progress。
  - `allocation_*` / `adjust_*` / `candidates_*` … 配分 CLI 入力。
- **対処**: 失敗プランは `input` あり `output` 無しパターンで predict 段階と断定しやすい。
- **関連**: server ログの `📁 [AGRR] Debug prediction_input saved to:` 行。

---

### #5 — agrr デーモン／ヘルプのハマり（2026-05-31）

- **症状**: `lib/core/agrr --help` がハング／`Resource temporarily unavailable`。
- **根拠**: 複数 `agrr --help` がソケットを掴んだ状態で `bin/agrr_client` も EAGAIN。
- **切り分け**: `lib/core/agrr daemon status`；`ps` で重複プロセス。
- **対処**: ハングクライアントを kill → `daemon stop` → `rm /tmp/agrr.sock` → `daemon start`。ヘルプは `bin/agrr_client weather --help`（デーモン経由）が確実。
- **関連**: `bin/agrr_client` は常に Unix ソケット。

---

### #6 — 本番 Cloud Run イメージの agrr CLI と最適化チェーン停止（2026-06-02）

- **症状**: 公開プランが `initializing` のまま。Cloud Logging に `optimization chain enqueued plan_id=N` のみで `finalized` / `WeatherPrediction` なし。
- **根拠**:
  - 本番 Job（`agrr-production` 同イメージ）で `agrr weather` **直叩き** → `Daemon is not running`（exit 1）。
  - 同 Job で `daemon start` → socket 待ち → `weather`（Bhopal, `nasa-power`, 欠損 223 日）→ **約3秒・records 223・exit 0**（2026-06-01）。
  - ローカル `lib/core/agrr weather` 直叩きも同条件で成功。
  - 本番 DB: `region=in` 農場は `determine_data_source` → `nasa-power`。チェーン窓（latest=2025-10-15, today≈2026-06-01）の DB 件数は窓の **80%超** → `FetchWeatherDataPerformInteractor` は **agrr API をスキップ**する想定。
- **切り分け**: [`production-admin/scripts/run-production-agrr-cli.sh`](../../production-admin/scripts/run-production-agrr-cli.sh) の `weather --preset bhopal-gap`；[`production-primary-sqlite-query`](../../production-primary-sqlite-query/SKILL.md) で `optimization_phase`。
- **対処**: agrr 気象 API 自体は本番イメージでもデーモン起動後は問題なし。**チェーン未進行は別因**（in-process `JobChainDispatcher`、SQLite ロック等）を調査。手動検証用 Job は `delete-job` で削除可。
- **関連**: `Dockerfile.agrr-server`（`/usr/local/bin/agrr`）、`crates/agrr-server/src/jobs.rs`、`optimization_job_chain.rs`。
