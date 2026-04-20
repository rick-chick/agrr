# agrr Gateway v1 → v2 統一 移行計画

## 現状（2026-04 時点）

### 実装配置

| ファイル | 役割 |
|---------|------|
| `app/gateways/agrr/base_gateway.rb` | **v1**。`Open3` 直叩きの `execute_command`。例外: `ExecutionError`, `ParseError`, `NoAllocationCandidatesError` |
| `app/gateways/agrr/base_gateway_v2.rb` | **v2**。`AgrrService`（デーモン／CLI）経由のコマンドディスパッチ。同名の例外クラスを再定義 |
| `app/gateways/agrr/*.rb`（9 本） | いずれも **`BaseGatewayV2` を継承**（`adjust`, `allocation`, `candidates`, `fertilize`, `optimization`, `prediction`, `progress`, `schedule`, `weather`） |

### v1 基底クラスに**直接**依存しているコード（`rg` 基準）

以下は **`Agrr::BaseGateway::...` の例外型**のみ参照しており、v1 の `execute_command` 実装には依存していない。

| 参照元 | 用途 |
|--------|------|
| `app/jobs/predict_weather_data_job.rb` | `retry_on` / `rescue` で `ExecutionError`, `ParseError` |
| `app/controllers/concerns/agrr_optimization.rb` | `rescue Agrr::BaseGateway::ExecutionError` |

### 重複・リスク

- 例外クラスが v1 / v2 で**別定義**のため、将来 v1 ファイルを削除すると上記 `rescue` が **`NameError` または誤った rescue** になりうる。
- 新規コードが誤って v1 の `BaseGateway` を継承する余地が残る。

## 目標状態（ロードマップ T-015 完了後の次フェーズ）

1. **単一の** `app/gateways/agrr/base_gateway.rb` のみを残す。
2. クラス名は **`Agrr::BaseGateway`**（現 v2 実装を本体とする）。
3. 全 gateway の継承元を **`Agrr::BaseGateway`** に統一（`< BaseGatewayV2` を廃止）。
4. `predict_weather_data_job` / `agrr_optimization` の例外参照は **`Agrr::BaseGateway::*` のまま**でよい（v2 側に定義を集約）。
5. `base_gateway_v2.rb` は削除（内容は `base_gateway.rb` にリネーム統合）。

## 移行手順（実装チェックリスト）

1. **`rg -n "BaseGatewayV2|base_gateway_v2"`** で参照をゼロにする。
2. **`base_gateway_v2.rb` の内容**を `base_gateway.rb` に移し、クラス名を `BaseGateway` に変更。既存の v1 `base_gateway.rb` は上書き削除。
3. 各 `*Gateway` の `class X < BaseGatewayV2` を `class X < BaseGateway` に置換。
4. **`require` / autoload**：`base_gateway_v2.rb` への参照が無いことを確認。
5. **テスト**: `./bin/test test/gateways/agrr`、`./bin/test test/controllers/api/v1/plans`、`./bin/test test/controllers/api/v1/public_plans`、必要に応じて `scripts/test_agrr_integration.rb`。
6. **ドキュメント**: 本ファイルの「現状」を「完了」に更新し、`ARCHITECTURE.md` の gateway 節が単一基底であることを明記。

## v1 と v2 の挙動差分（統合時の注意点）

- v1 は `Open3.capture3` + タイムアウトで生バイナリを実行。v2 は `AgrrService` 経由でデーモン／エラーメッセージの正規化が入る。
- **統合後は v2 の例外マッピング**（`DaemonNotRunningError` → `ExecutionError` 等）が標準となる。ジョブのリトライ条件は、統合後も `ExecutionError` / `ParseError` で問題ないことをテストで確認する。
- v1 独自の stdout 先頭 `Error` / `❌` 判定は v2 では `AgrrService` 側に寄っているため、**統合後にのみ発現する**エラーパスがないかログ／統合テストで確認する。

## 依存関係

- **T-031**（`cultivation_plan_optimizer` の Interactor 化）や **optimization_gateway** を広く触る前に、本統合を完了させることを推奨（基底・例外の二重定義を解消してからの方が差分が明確）。
