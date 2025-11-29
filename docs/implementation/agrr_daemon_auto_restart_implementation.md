# agrr daemon自動起動・リトライ処理 実装設計書

## 実装方針

`AgrrService#execute_command` メソッド内で、agrr daemonが起動していないことによる実行失敗を検出し、自動的にdaemonを起動してからリトライする処理を実装する。

## 実装箇所

**対象ファイル**: `app/services/agrr_service.rb`
**対象メソッド**: `execute_command` (173-214行目)

## 現在の処理フロー

1. 各メソッド（weather, forecast, crop等）で `daemon_running?` をチェック
   - 起動していない場合: `DaemonNotRunningError` をraiseして即座に終了
2. `execute_command` が呼ばれる
3. `Open3.capture3` で `bin/agrr_client` を実行
4. エラー時（非ゼロexit code）は `CommandExecutionError` をraise

## 実装後の処理フロー

1. 各メソッド（weather, forecast, crop等）で `daemon_running?` をチェック
   - 起動していない場合: `DaemonNotRunningError` をraise
   - **変更点**: この時点ではエラーをraiseせず、`execute_command` に処理を委譲するように変更（または `execute_command` 内でチェック）
2. `execute_command` が呼ばれる
3. 初回実行を試みる
4. エラー発生時:
   - `DaemonNotRunningError` またはソケット接続エラー（`CommandExecutionError`）を検出
   - daemonが起動していない可能性があると判断
   - agrr daemonを自動起動
   - 数秒待機してdaemonが起動するのを確認
   - **1回のみ**リトライ
5. リトライ後もエラーが発生した場合は、通常のエラー処理に任せる

## 実装詳細

### 1. daemon自動起動メソッドの追加

`AgrrService` に以下のprivateメソッドを追加:

```ruby
def start_daemon_if_not_running
  return true if daemon_running?
  
  agrr_bin = find_agrr_binary
  unless agrr_bin
    Rails.logger.warn "[AgrrService] AGRR binary not found, skipping daemon auto-start"
    return false
  end
  
  Rails.logger.info "[AgrrService] AGRR daemon is not running, attempting to start..."
  
  # daemon startコマンドを実行
  stdout, stderr, status = Open3.capture3(agrr_bin, 'daemon', 'start')
  
  unless status.success?
    Rails.logger.error "[AgrrService] Failed to start AGRR daemon: #{stderr}"
    return false
  end
  
  # daemonが起動するまで待機（最大5秒、0.5秒間隔でポーリング）
  max_wait_time = 5.0
  poll_interval = 0.5
  elapsed = 0.0
  
  while elapsed < max_wait_time
    sleep(poll_interval)
    elapsed += poll_interval
    
    if daemon_running?
      Rails.logger.info "[AgrrService] AGRR daemon started successfully (waited #{elapsed.round(1)}s)"
      return true
    end
  end
  
  Rails.logger.warn "[AgrrService] AGRR daemon may not have started within #{max_wait_time}s"
  daemon_running?
end

def find_agrr_binary
  # 環境変数から取得を試みる
  agrr_bin = ENV['AGRR_BIN_PATH']
  return agrr_bin if agrr_bin && File.executable?(agrr_bin)
  
  # デフォルトパスを確認
  default_path = '/usr/local/bin/agrr'
  return default_path if File.executable?(default_path)
  
  nil
end
```

### 2. `execute_command` メソッドの修正

`execute_command` メソッドを以下のように修正:

```ruby
def execute_command(args, retried: false)
  Rails.logger.info "Executing AGRR command: #{args.join(' ')}"
  
  stdout, stderr, status = Open3.capture3(@client_path.to_s, *args)
  
  # 既存のログ出力処理...
  # ... (省略) ...
  
  if status.success?
    clean_output || stdout
  elsif has_valid_json && stderr.blank?
    # 既存の処理...
    clean_output || stdout
  else
    error_message = stderr.presence || "Command failed with exit code #{status.exitstatus}"
    
    # エラーがdaemon未起動に関連する可能性があるかチェック
    if !retried && should_retry_with_daemon_start?(error_message, stderr)
      Rails.logger.info "[AgrrService] Command failed, attempting to start daemon and retry..."
      
      if start_daemon_if_not_running
        # daemon起動に成功したらリトライ（1回のみ）
        return execute_command(args, retried: true)
      else
        Rails.logger.warn "[AgrrService] Failed to start daemon, proceeding with original error"
      end
    end
    
    Rails.logger.error "AGRR command failed: #{error_message}"
    raise CommandExecutionError, error_message
  end
rescue => e
  # 予期しないエラー（例: ソケット接続エラー）もリトライ対象とする
  if !retried && e.is_a?(Errno::ECONNREFUSED) || e.message.include?('socket') || e.message.include?('Connection refused')
    Rails.logger.info "[AgrrService] Connection error detected, attempting to start daemon and retry..."
    
    if start_daemon_if_not_running
      return execute_command(args, retried: true)
    end
  end
  
  raise
end
```

### 3. daemon未起動エラー判定メソッドの追加

```ruby
def should_retry_with_daemon_start?(error_message, stderr)
  # stderrやerror_messageにdaemon未起動を示す文字列が含まれているかチェック
  combined_error = "#{error_message} #{stderr}".downcase
  
  combined_error.include?('connection refused') ||
    combined_error.include?('no such file') ||
    combined_error.include?('socket') ||
    combined_error.include?('daemon') ||
    !daemon_running?
end
```

### 4. 各メソッドの `daemon_running?` チェックについて

**オプションA: チェックを削除して `execute_command` で統一処理**
- メリット: 処理を一箇所に集約できる
- デメリット: 各メソッドでの早期チェックがなくなる

**オプションB: チェックは残すが、`execute_command` でも自動起動処理を実装**
- メリット: 早期チェックと自動起動の両方が機能する
- デメリット: `daemon_running?` チェックで `DaemonNotRunningError` がraiseされると `execute_command` まで到達しない

**推奨: オプションA**
各メソッドの `daemon_running?` チェックを削除し、`execute_command` 内で統一して処理する。これにより、エラーハンドリングが一箇所に集約される。

ただし、既存のコントローラーで `DaemonNotRunningError` を捕捉している場合、`execute_command` 内で自動起動に失敗した場合に `DaemonNotRunningError` をraiseするようにする必要がある。

## エラー検出パターン

### パターン1: `DaemonNotRunningError` が各メソッドでraiseされる
**現在の動作**: 各メソッドで `daemon_running?` が `false` の場合に即座に `DaemonNotRunningError` をraise

**実装後の動作**:
- オプションA: チェックを削除し、`execute_command` で処理
- オプションB: チェック時に自動起動を試みる（チェックを修正）

### パターン2: ソケット接続失敗
**現在の動作**: `bin/agrr_client` がソケット接続に失敗し、Python例外が発生。`Open3.capture3` で捕捉され、非ゼロexit codeが返る

**実装後の動作**: `execute_command` でエラーを検出し、daemon自動起動後にリトライ

### パターン3: コマンド実行エラー
**現在の動作**: agrr_clientが非ゼロexit codeを返し、`CommandExecutionError` がraiseされる

**実装後の動作**: エラーメッセージからdaemon未起動の可能性を判定し、該当する場合のみ自動起動・リトライ

## 実装時の考慮事項

### 1. agrr daemon起動方法

- **コマンド**: `agrr daemon start`
- **バイナリパス**: 
  - 環境変数 `AGRR_BIN_PATH` を優先
  - 未設定の場合はデフォルト `/usr/local/bin/agrr`
- **起動確認**: ソケットファイル `/tmp/agrr.sock` の存在とソケットタイプを確認

### 2. 起動待機時間

- **ポーリング間隔**: 0.5秒
- **最大待機時間**: 5秒
- **確認方法**: `daemon_running?` メソッドを使用（ソケットファイルの存在確認）

### 3. リトライ制御

- **リトライ回数**: 1回のみ（`retried` フラグで制御）
- **リトライ条件**: 
  - daemon未起動に関連するエラーの場合
  - 自動起動に成功した場合
- **リトライ後のエラー**: 通常のエラー処理（`CommandExecutionError` をraise）

### 4. 権限・バイナリチェック

- agrrバイナリの存在確認
- バイナリの実行権限確認
- バイナリが見つからない場合や権限がない場合は自動起動をスキップ

### 5. ログ出力

以下のタイミングでログを出力:
- daemon自動起動を試みる際: `INFO` レベル
- daemon起動成功時: `INFO` レベル（待機時間も記録）
- daemon起動失敗時: `ERROR` レベル
- リトライ実行時: `INFO` レベル

### 6. 既存のエラーハンドリングとの整合性

- コントローラーでの `DaemonNotRunningError` 捕捉は維持
- 自動起動に失敗した場合は、従来通り `DaemonNotRunningError` をraise
- Gateway層でのエラーハンドリング（`BaseGatewayV2`）は変更不要

## テスト方針

### 1. 単体テスト (`test/services/agrr_service_test.rb`)

- daemon未起動時の自動起動・リトライ成功ケース
- daemon自動起動失敗ケース
- daemonが既に起動している場合の通常処理
- リトライ回数の制限確認（1回のみ）
- agrrバイナリが見つからない場合のスキップ確認

### 2. 統合テスト

- 実際にdaemonを起動・停止してテスト
- ソケット接続エラー時の自動起動確認

## 関連ファイル

### 修正対象
- `app/services/agrr_service.rb` - メイン実装箇所

### テストファイル
- `test/services/agrr_service_test.rb` - 単体テスト

### 参考ファイル
- `bin/agrr_client` - agrrクライアント（ソケット接続の実装）
- `scripts/start_app.sh` - daemon起動スクリプト（起動方法の参考）
- `app/gateways/agrr/base_gateway_v2.rb` - Gateway層（エラーハンドリングの参考）

## 実装手順

1. `AgrrService` に `start_daemon_if_not_running` メソッドを追加
2. `AgrrService` に `find_agrr_binary` メソッドを追加
3. `AgrrService` に `should_retry_with_daemon_start?` メソッドを追加
4. `execute_command` メソッドを修正して自動起動・リトライ処理を追加
5. （オプション）各メソッドの `daemon_running?` チェックを削除
6. テストを追加・更新
7. 動作確認

## 注意事項

- 自動起動は1回のみ試行し、無限ループを避ける
- daemon起動は非同期で実行されるため、起動完了を適切に待機する
- バイナリが見つからない場合や権限がない場合は、エラーをraiseせずスキップする
- 既存のエラーハンドリングフローを壊さないように注意する

