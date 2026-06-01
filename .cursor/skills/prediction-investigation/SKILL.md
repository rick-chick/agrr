---
name: prediction-investigation
description: >-
  Investigates weather fetch and ML prediction failures in public/private plan
  optimization chains (agrr-server, agrr daemon). Use for predicting_weather phase
  failed, weather_prediction failed, initializing stuck, India/global weather, or
  天気予報・予測・prediction_input・tmp/debug. Production agrr CLI on Cloud Run:
  production-admin run-production-agrr-cli.sh.
disable-model-invocation: true
---

# 予測系調査スキル

公開プラン／栽培計画の最適化チェーンで **気象取得 → 気象予測（lightgbm 等）→ 最適化** のどこで落ちたかを切り分け、根拠を `tmp/debug`・ログ・DB・agrr CLI で確認する。修正は本スキル外（[`error-investigation`](../error-investigation/SKILL.md) → [`error-fix-red-green`](../error-fix-red-green/SKILL.md) / [`tdd-on-edit`](../tdd-on-edit/SKILL.md)）。

**知見の蓄積先**: 調査で確定したパターンは必ず [`references/KNOWLEDGE.md`](references/KNOWLEDGE.md) に追記する（日付・根拠・再現手順を 1 ブロック）。

## When to Use

- UI: `phase_failed.predicting_weather` / 「天気データの予測に失敗」/ ヒンディー `मौसम डेटा की भविष्यवाणी में विफल`
- ログ: `weather_prediction failed plan_id=`
- `tmp/debug/prediction_*` の確認・比較
- インド（`region: in`）や参照農場の気象・予測の不具合疑い
- Trigger: 予測調査, 天気予報, weather prediction, predicting_weather, prediction debug

## Instructions

### Phase 0: 事象と経路

1. **失敗フェーズ**を UI / ActionCable / `cultivation_plans.phase` から特定する。
   - `fetching_weather` → 履歴取得（`FetchWeatherDataJob` / chain `weather` step）
   - `predicting_weather` → **本スキルの中心**（`WeatherPredictionJob` / `run_weather_prediction_step`）
   - `optimizing` 以降 → [`error-investigation`](../error-investigation/SKILL.md) へ委譲しつつ、予測成果物の有無だけ確認
2. **バックエンド経路**: [`dev-docker`](../dev-docker/SKILL.md)（Compose）vs `host-rust-stack.sh`。環境変数の読み込みプロセスが違う（後述 KNOWLEDGE）。
3. [`references/INVESTIGATION_FLOW.md`](references/INVESTIGATION_FLOW.md) のチェックリストに沿って進める。

### Phase 1: ログと debug ダンプ

4. **Rust 開発**: `tail -80 /tmp/agrr-dev-rust-pids/rust.log`（`weather_prediction failed` / `weather fetch`）。
5. **`tmp/debug/`**（`AGRR_ENV` / `RAILS_ENV` が production 以外）:
   - `prediction_input_*` … agrr `predict` に渡した **学習用** JSON（`PredictionDaemonGateway` が保存）
   - `prediction_output_*` … 成功時のみ
   - 入力の日付分布を必ず見る（KNOWLEDGE「日付が 1 日に潰れる」）
6. 最新の `prediction_input_*.json` を Python で要約（手順は INVESTIGATION_FLOW）。

### Phase 2: DB・agrr CLI

7. **SQLite**（開発 DB）: 対象 `weather_location_id` の `MIN(date)`, `MAX(date)`, `COUNT(DISTINCT date)`。行はあるが予測だけ失敗 → 読み取り／predict 側を疑う。
8. **agrr デーモン**: `lib/core/agrr daemon status`。詰まったら `daemon stop` → socket 削除 → `daemon start`。
9. **CLI 切り分け**（`bin/agrr_client`、長い処理は `--output` 必須）:
   - `weather --data-source nasa-power` vs `noaa`（インド座標）
   - `predict --model arima` vs `lightgbm`（同一 `prediction_input` で比較）

### Phase 2b: 本番 agrr CLI（責務外 → production-admin）

本番イメージでの `agrr weather` 切り分けは **[`production-admin`](../production-admin/SKILL.md)** の [`run-production-agrr-cli.sh`](../production-admin/scripts/run-production-agrr-cli.sh)。本番 DB は [`production-primary-sqlite-query`](../production-primary-sqlite-query/SKILL.md)。要点は KNOWLEDGE #6（デーモン必須・ローカル成功≠チェーン進行）。

### Phase 3: パターン照合と記録

13. 症状を [`references/KNOWLEDGE.md`](references/KNOWLEDGE.md) の表と照合。
14. **新規パターン**なら KNOWLEDGE に追記（テンプレートは同ファイル末尾）。
15. 原因がコードバグと確定したら調査を止め、RED 用の再現テスト方針を 1 行で残してから [`error-fix-red-green`](../error-fix-red-green/SKILL.md) へ。

## 関連コード（入口）

| 層 | パス |
|----|------|
| チェーン | `crates/agrr-server/src/optimization_job_chain.rs`, `optimization_chain_run.rs` (`run_weather_prediction_step`) |
| ドメイン予測 | `crates/agrr-domain/src/weather_data/interactors/weather_prediction_interactor.rs`（既定 model: `lightgbm`） |
| agrr 予測 | `crates/agrr-adapters-agrr/src/prediction_daemon_gateway.rs` |
| 気象取得 data source | `fetch_weather_data_perform_interactor` + `WEATHER_DATA_SOURCE` |
| SQLite 日付読取 | `crates/agrr-adapters-sqlite/src/weather_data/weather_data_gateway.rs` |
| debug 保存 | `crates/agrr-adapters-agrr/src/agrr_daemon_debug_dump.rs` |
| 開発起動 | `scripts/dev-rust-stack.sh` |

## References

- [references/INVESTIGATION_FLOW.md](references/INVESTIGATION_FLOW.md) — 手順・コマンド例
- [references/KNOWLEDGE.md](references/KNOWLEDGE.md) — **蓄積知見（随時更新）**
- [test-common](../test-common/SKILL.md) — テスト実行
- [process-monitor](../process-monitor/SKILL.md) — agrr / cargo の完了待ち
