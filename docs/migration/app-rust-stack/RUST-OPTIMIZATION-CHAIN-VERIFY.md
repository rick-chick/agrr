# Rust 最適化チェーン — ローカル確認手順

公開／私有プラン作成後の **気象取得 → 予測 → allocate → 完了** を `agrr-server` の in-process ジョブチェーンで実行する。Rails の `PublicPlanOptimizationJobChainActiveRecordGateway` 相当。

## 前提

| 項目 | 内容 |
|------|------|
| DB | `storage/development.sqlite3`（`AGRR_SQLITE_PATH`） |
| agrr デーモン | `/tmp/agrr.sock`（`USE_AGRR_DAEMON=true docker compose up` 等） |
| 予測（開発） | 既定 `AGRR_USE_MOCK=true`（LightGBM は `AGRR_USE_MOCK=false` + `AGRR_PREDICT_MODEL=lightgbm`） |

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
export AGRR_USE_MOCK=true

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

## トラブルシュート

| 症状 | 確認 |
|------|------|
| `agrr daemon not running` | `ls -l /tmp/agrr.sock`、`USE_AGRR_DAEMON=true` |
| `predicting_weather` で failed | `AGRR_USE_MOCK=true`、daemon の `block_on` エラーは `daemon_client` 修正済み |
| `field_cultivations=0` で completed | allocate 候補 0 件（作物 `stage_requirements` 不足・期間・天気）。spike の `agrr_payload_build`（Calculator 経路）を参照 |
| 進捗が動かない | 計画 `status` が `optimizing` か、Rust サーバーが起動しているか |

## 関連コード

- `crates/agrr-server/src/optimization_job_chain.rs` — チェーン定義
- `crates/agrr-server/src/optimization_chain_run.rs` — 各ステップ実装（optimize は Interactor 委譲）
- `crates/agrr-server/src/cultivation_plan_optimize.rs` — `CultivationPlanOptimizeInteractor` 配線
- `crates/agrr-domain/src/cultivation_plan/interactors/cultivation_plan_optimize_interactor.rs` — Rails `CultivationPlanOptimizeInteractor` 相当
- `crates/agrr-server/src/cable.rs` — 購読直後スナップショット
