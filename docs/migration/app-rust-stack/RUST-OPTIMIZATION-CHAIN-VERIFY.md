# Rust 最適化チェーン — ローカル確認手順

公開／私有プラン作成後の **気象取得 → 予測 → allocate → 完了** を `agrr-server` の in-process ジョブチェーンで実行する。Rails の `PublicPlanOptimizationJobChainActiveRecordGateway` 相当。

## 前提

| 項目 | 内容 |
|------|------|
| DB | `storage/development.sqlite3`（`AGRR_SQLITE_PATH`） |
| agrr デーモン | `/tmp/agrr.sock`（`USE_AGRR_DAEMON=true docker compose up` 等） |
| 予測（開発） | 既定は実 agrr（`lightgbm`）。モックのみ `AGRR_USE_MOCK=true` |

## 一括確認（推奨）

```bash
chmod +x scripts/verify-rust-optimization-chain.sh

# 前提チェック + spike
bash scripts/verify-rust-optimization-chain.sh

# さらに plan をリセットして completed まで実行
RUN_CHAIN=1 PLAN_ID=14 bash scripts/verify-rust-optimization-chain.sh
```

成功時: spike がすべて `[OK]`、オプションの chain で `status=completed`。

## 個別コマンド

```bash
export AGRR_SQLITE_PATH=storage/development.sqlite3
# 予測をモックにする場合のみ:
# export AGRR_USE_MOCK=true

# ビルド
cargo build -p agrr-server --bins

# 技術検証（デーモン・SQLite・allocate プローブ）
# agrr_payload_build / allocate は OptimizationAllocationInputCalculator 経路（Rails prepare_allocation_data 相当）
cargo run -p agrr-server --bin optimization-chain-spike -- --plan-id 14

# 1 プランのチェーン実行（ポーリング付き）
cargo run -p agrr-server --bin optimization-chain-run -- --plan-id 14

# ステップ単体（デバッグ）
cargo run -p agrr-server --bin optimization-chain-run -- --plan-id 14 --step fetch
cargo run -p agrr-server --bin optimization-chain-run -- --plan-id 14 --step predict
cargo run -p agrr-server --bin optimization-chain-run -- --plan-id 14 --step optimize
```

## UI / API 経由（strangler）

```bash
bash scripts/e2e-strangler-stack.sh
# Angular: http://localhost:4200
# API 経 nginx: http://localhost:3000 → agrr-server :8080
# WebSocket: /cable（進捗は OptimizationChannel / PlansOptimizationChannel）
```

公開プラン作成 API が Rust に向いている環境では、作成直後に `enqueue_private_plan_optimization_chain` が走る。

## 天気予測と optimize allocate（Rails 同等）

**allocate（`optimize` ステップ）の実行中に新規の天気予測（agrr `predict`）は走らない。** 既に SQLite に保存された予測 JSON を読み、`optimize allocate` の `--weather-file` に渡すだけ。Rust は Rails と同じ分離である。

| ステップ | 新規予測（agrr `predict`） | Rails | Rust |
|----------|------------------------------|-------|------|
| チェーン `predict` | **する** | `WeatherPredictionJob` → `WeatherPredictionInteractor#predict_for_cultivation_plan` | `run_weather_prediction_step` → 同上 |
| チェーン `optimize`（allocate） | **しない**（キャッシュのみ） | `OptimizationJob` → `CultivationPlanOptimizeInteractor#get_existing_prediction` | `CultivationPlanOptimizeInteractor::call` → `WeatherPredictionService#get_existing_prediction` |
| agrr `optimize allocate` | **しない** | `PlanAllocationAllocateAgrrDaemonGateway`（`--weather-file`） | `PlanAllocationAllocateAgrrDaemonGateway`（同上） |

### Rails ではこう

1. **ジョブ順序**  
   - **Rails**（`PublicPlanOptimizationJobChainActiveRecordGateway#build_job_instances`）:  
     `FetchWeatherDataJob` → `WeatherPredictionJob` → `OptimizationJob` → `TaskScheduleGenerationJob`  
   - **Rust**（`optimization_job_chain.rs`）: 気象 → 予測 → optimize → finalize（**作業予定生成は含めない**）

2. **予測**（`app/jobs/weather_prediction_job.rb`）  
   `weather_prediction_service.predict_for_cultivation_plan(...)` で履歴＋agrr `predict`（LightGBM 等）を実行し、計画／農場／WeatherLocation の `predicted_weather_data` に永続化する。

3. **allocate**（`lib/domain/cultivation_plan/interactors/cultivation_plan_optimize_interactor.rb`）  
   `get_existing_prediction(target_end_date:, cultivation_plan_weather:)` のみ。無ければ  
   `天気予測データが存在しません。計画作成時に天気予測が実行されていません。`  
   ログ: `♻️ [Optimizer] Using existing prediction data`  
   `predict_for_cultivation_plan` は**呼ばない**。

4. **adjust / candidates との差**（Rails も Rust も同型）  
   `PlanAllocationAdjustInteractor` や candidates 用 lambda はキャッシュミス時に `predict_for_cultivation_plan` へフォールバックするが、**最適化 allocate にはそのフォールバックはない**。

`optimize` だけ単体実行する場合は、事前に `predict` ステップ（または計画作成時の予測）が成功している必要がある。

## トラブルシュート

| 症状 | 確認 |
|------|------|
| `agrr daemon not running` | `ls -l /tmp/agrr.sock`、`USE_AGRR_DAEMON=true` |
| `predicting_weather` で failed | agrr デーモン起動・`AGRR_SOCKET_PATH`、一時的に `AGRR_USE_MOCK=true` |
| optimize で「天気予測データが存在しません」 | `predict` 未実行または `predicted_weather_data` 空。チェーン順序・上記「天気予測と optimize allocate」を参照 |
| `field_cultivations=0` で completed | allocate 候補 0 件（作物 `stage_requirements` 不足・期間・天気）。spike の `agrr_payload_build`（Calculator 経路）を参照 |
| 進捗が動かない | 計画 `status` が `optimizing` か、Rust サーバーが起動しているか |

## 関連コード

- `app/adapters/public_plan/gateways/public_plan_optimization_job_chain_active_record_gateway.rb` — Rails ジョブチェーン組立
- `app/jobs/weather_prediction_job.rb` / `app/jobs/optimization_job.rb` — predict / optimize ジョブ
- `lib/domain/cultivation_plan/interactors/cultivation_plan_optimize_interactor.rb` — allocate 時は `get_existing_prediction` のみ
- `lib/domain/weather_data/interactors/weather_prediction_interactor.rb` — `get_existing_prediction` / `predict_for_cultivation_plan`
- `crates/agrr-server/src/optimization_job_chain.rs` — チェーン定義
- `crates/agrr-server/src/optimization_chain_run.rs` — 各ステップ実装（optimize は Interactor 委譲）
- `crates/agrr-server/src/cultivation_plan_optimize.rs` — `CultivationPlanOptimizeInteractor` 配線
- `crates/agrr-domain/src/cultivation_plan/interactors/cultivation_plan_optimize_interactor.rs` — Rails `CultivationPlanOptimizeInteractor` 相当
- `crates/agrr-server/src/cable.rs` — 購読直後スナップショット
