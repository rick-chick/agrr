# agrr daemon自動起動・リトライ処理 分析・実装設計書

## 概要
agrr daemonが起動していないためにagrrの実行に失敗した際、自動的にdaemonを起動してから実行をリトライする処理を追加する。

**実装箇所**: `AgrrService#execute_command` メソッド（`app/services/agrr_service.rb`）

詳細な実装設計は `docs/implementation/agrr_daemon_auto_restart_implementation.md` を参照。

## 現在のagrr実行フロー

### 1. agrr実行のエントリーポイント

#### AgrrService (`app/services/agrr_service.rb`)
- 各メソッド（weather, forecast, crop, progress, optimize, predict, schedule, fertilize_plan, pest_to_crop）でagrrコマンドを実行
- 各メソッドの最初で `daemon_running?` をチェック
  - 起動していない場合: `DaemonNotRunningError` をraise（23, 64, 74, 84, 94, 105, 117, 129, 139, 151, 164行目）
- `execute_command` メソッド（173-214行目）で `bin/agrr_client` を実行
  - `Open3.capture3` でコマンド実行
  - エラー時は `CommandExecutionError` をraise

#### BaseGatewayV2 (`app/gateways/agrr/base_gateway_v2.rb`)
- `execute_command` メソッド（17-82行目）で `AgrrService` を使用
- `DaemonNotRunningError` を捕捉して `ExecutionError` に変換（62-64行目）
- `CommandExecutionError` も捕捉して処理（65-77行目）

#### コントローラー
- `Api::WeatherController` (31, 56行目)
- `Api::V1::CropsController` (86行目)
- `Api::V1::PestsController` (291行目)
- などで `DaemonNotRunningError` を捕捉してエラーレスポンスを返す

### 2. agrrクライアント (`bin/agrr_client`)
- Unixソケット `/tmp/agrr.sock` に接続してagrr daemonと通信
- ソケット接続失敗時はPython例外が発生する可能性がある
- この例外は `AgrrService#execute_command` で捕捉される

### 3. agrr daemonの起動方法
- コマンド: `agrr daemon start`
- バイナリパス: 環境変数 `AGRR_BIN_PATH` またはデフォルト `/usr/local/bin/agrr`
- ソケットパス: `/tmp/agrr.sock`
- 起動スクリプト: `scripts/start_app.sh` などで起動処理がある

## エラー発生箇所の特定

### パターン1: `daemon_running?` チェックでエラー
**発生箇所**: `AgrrService` の各メソッド
- 例: `AgrrService#weather` (23行目)
- エラー: `DaemonNotRunningError`
- 発生条件: `/tmp/agrr.sock` が存在しない、またはソケットファイルではない

### パターン2: ソケット接続失敗
**発生箇所**: `bin/agrr_client` の `sock.connect(SOCKET_PATH)` (31行目)
- エラー: Pythonの `ConnectionRefusedError` や `FileNotFoundError` など
- この例外は `AgrrService#execute_command` で捕捉されて `CommandExecutionError` になる可能性

### パターン3: コマンド実行時のエラー
**発生箇所**: `AgrrService#execute_command` (173-214行目)
- エラー: `CommandExecutionError`
- 発生条件: agrr_clientが非ゼロのexit codeを返し、かつ有効なJSONが含まれていない場合

## 実装箇所: `AgrrService#execute_command`

**決定**: `AgrrService#execute_command` メソッドで自動起動・リトライ処理を実装する。

### 決定理由

1. **全てのagrr実行が通過**: 全てのメソッドが `execute_command` を使用
2. **エラーを網羅**: `DaemonNotRunningError` だけでなく、ソケット接続エラーも捕捉可能
3. **一箇所で統一**: 処理を一箇所に集約できる
4. **既存コードへの影響が少ない**: Service層での処理のため、Gateway層やController層への影響が少ない

### 実装方針

1. `execute_command` 内でエラー発生
2. daemon未起動に関連するエラーを検出（`DaemonNotRunningError`、ソケット接続エラー等）
3. agrr daemonを自動起動（`agrr daemon start`）
4. 数秒待機してdaemonが起動するのを確認（ポーリング、最大5秒）
5. 1回のみリトライ
6. リトライ後もエラーが発生した場合は、通常のエラー処理に任せる

詳細な実装内容は `docs/implementation/agrr_daemon_auto_restart_implementation.md` を参照。

## 実装時の考慮事項（要約）

詳細は `docs/implementation/agrr_daemon_auto_restart_implementation.md` を参照。

### 主要な考慮事項

1. **agrr daemon起動方法**: 環境変数 `AGRR_BIN_PATH` またはデフォルト `/usr/local/bin/agrr`
2. **起動待機時間**: ポーリング間隔0.5秒、最大待機時間5秒
3. **リトライ回数**: 1回のみ（`retried` フラグで制御）
4. **権限チェック**: バイナリの存在・実行権限を確認
5. **ログ出力**: 自動起動・リトライ時に適切なログを出力
6. **エラーハンドリング**: 既存のエラーハンドリングフローを維持

## 関連ファイル

### 実装対象
- `app/services/agrr_service.rb` - **実装箇所**（`execute_command` メソッド）

### 参考ファイル
- `bin/agrr_client` - agrrクライアント（ソケット接続の実装）
- `app/gateways/agrr/base_gateway_v2.rb` - Gateway層でのエラーハンドリング
- `app/controllers/api/weather_controller.rb` - コントローラー層でのエラーハンドリング
- `scripts/start_app.sh` - daemon起動スクリプト（起動方法の参考）

### ドキュメント
- `docs/implementation/agrr_daemon_auto_restart_implementation.md` - 詳細な実装設計書

