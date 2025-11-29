# 本番環境起動最適化検討

## 現状の起動処理

`scripts/start_app.sh` で以下の処理が順次実行されています：

1. **Litestream restore** (Step 1)
   - メインデータベース: `/tmp/production.sqlite3`
   - キューデータベース: `/tmp/production_queue.sqlite3`
   - キャッシュデータベース: `/tmp/production_cache.sqlite3`
   - 時間: GCSからのダウンロード時間に依存（数秒〜数十秒）

2. **db:migrate** (Step 2)
   - 全データベースのマイグレーション実行
   - 時間: マイグレーション数に依存（数秒〜数分）

3. **agrr daemon start** (Step 3) - オプション
   - agrrデーモンの起動
   - 時間: 数秒

4. **Litestream replicate** (Step 4)
   - バックグラウンドでレプリケーション開始
   - 時間: 即座に戻る（バックグラウンド処理）

5. **Solid Queue worker** (Step 5)
   - バックグラウンドジョブワーカーの起動
   - 時間: 数秒

6. **Rails server** (Step 6)
   - サーバー起動（フォアグラウンド）
   - 時間: Rails初期化時間（数秒〜数十秒）

## 最適化案

### 案1: 最小限の起動処理のみ実行（推奨）

**方針**: サーバー起動に必要な最小限の処理のみを同期的に実行し、その他はバックグラウンドまたは遅延実行

#### 実装内容

1. **必須処理（同期的に実行）**
   - メインデータベースの復元（最小限のデータのみ）
   - メインデータベースのマイグレーション（必須）
   - Railsサーバー起動

2. **バックグラウンド処理（非同期実行）**
   - キュー/キャッシュデータベースの復元
   - キュー/キャッシュデータベースのマイグレーション
   - agrr daemon起動
   - Litestream replicate開始
   - Solid Queue worker起動

3. **遅延実行（起動後にジョブで実行）**
   - 完全なデータベース復元（必要に応じて）
   - キャッシュウォームアップ（必要に応じて）

#### 注意点

- **データベース整合性**: メインデータベースが利用可能になるまで、キュー/キャッシュが利用できない
- **ヘルスチェック**: `/up` エンドポイントがデータベース接続を確認する場合、メインデータベースが利用可能である必要がある
- **初回リクエスト**: 起動直後のリクエストがキュー/キャッシュを必要とする場合、エラーになる可能性
- **マイグレーション順序**: キュー/キャッシュのマイグレーションが失敗した場合のエラーハンドリング

### 案2: 並列実行による高速化

**方針**: 可能な処理を並列実行して全体の起動時間を短縮

#### 実装内容

1. **並列実行**
   - 3つのデータベースの復元を並列実行
   - 3つのデータベースのマイグレーションを並列実行（依存関係がない場合）

2. **非同期実行**
   - agrr daemon、Litestream replicate、Solid Queue workerを並列起動

#### 注意点

- **リソース競合**: 並列実行によるI/O競合の可能性
- **エラーハンドリング**: 並列実行中のエラー処理が複雑になる

### 案3: 段階的起動（推奨）

**方針**: 最小限の起動 → 基本機能の利用可能 → 完全起動の3段階

#### 実装内容

1. **Phase 1: 最小起動（数秒）**
   - メインデータベースの最小限の復元（スキーマのみ）
   - メインデータベースのマイグレーション
   - Railsサーバー起動（読み取り専用モード）

2. **Phase 2: 基本機能（バックグラウンド）**
   - キュー/キャッシュデータベースの復元とマイグレーション
   - Solid Queue worker起動
   - 書き込み機能の有効化

3. **Phase 3: 完全起動（バックグラウンド）**
   - 完全なデータベース復元
   - agrr daemon起動
   - Litestream replicate開始
   - キャッシュウォームアップ

#### 注意点

- **読み取り専用モード**: 起動直後は読み取りのみ可能にする必要がある
- **機能制限**: 書き込み機能が利用可能になるまでの待機時間
- **ユーザー体験**: 段階的な機能有効化をユーザーに通知する必要がある

## 推奨実装: 案1（最小限の起動処理）

### 実装詳細

#### 1. 起動スクリプトの最適化

```bash
# Step 1: メインデータベースのみ復元（必須）
litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production.sqlite3

# Step 2: メインデータベースのみマイグレーション（必須）
bundle exec rails db:migrate

# Step 3: Railsサーバー起動（フォアグラウンド）
# その他の処理はバックグラウンドで実行
```

#### 2. バックグラウンド処理の実装

起動後にジョブで実行する処理：

- キュー/キャッシュデータベースの復元とマイグレーション
- agrr daemon起動
- Litestream replicate開始
- Solid Queue worker起動

#### 3. 遅延実行ジョブの作成

```ruby
# app/jobs/startup_background_job.rb
class StartupBackgroundJob < ApplicationJob
  queue_as :default

  def perform
    # キュー/キャッシュデータベースの復元とマイグレーション
    # agrr daemon起動
    # その他の初期化処理
  end
end
```

### 注意点と対策

#### 1. データベース整合性

- **問題**: キュー/キャッシュが利用できない間、バックグラウンドジョブが実行できない
- **対策**: 
  - メインデータベースのマイグレーション完了後に、キュー/キャッシュの復元とマイグレーションを優先的に実行
  - キュー/キャッシュが利用可能になるまで、バックグラウンドジョブを待機させる仕組み

#### 2. ヘルスチェック

- **問題**: `/up` エンドポイントが全データベースの接続を確認する場合、起動が遅くなる
- **対策**: 
  - メインデータベースのみを確認する軽量なヘルスチェックエンドポイントを作成
  - 完全なヘルスチェックは別エンドポイント（`/up/full`）に分離

#### 3. 初回リクエスト

- **問題**: 起動直後のリクエストがキュー/キャッシュを必要とする場合、エラーになる
- **対策**: 
  - キュー/キャッシュが利用可能になるまで、エラーハンドリングで適切に処理
  - または、キュー/キャッシュが利用可能になるまで、該当機能を無効化

#### 4. マイグレーションエラー

- **問題**: バックグラウンドで実行されるマイグレーションが失敗した場合の検知
- **対策**: 
  - マイグレーション失敗時にログに記録
  - 監視システムでアラートを設定
  - 定期的にマイグレーション状態を確認するジョブ

#### 5. Cloud Runの起動タイムアウト

- **問題**: Cloud Runの起動タイムアウト（デフォルト: 300秒）を超える可能性
- **対策**: 
  - 最小限の起動処理のみを同期的に実行
  - タイムアウト時間を延長（必要に応じて）

## 実装状況

### ✅ Phase 1: 最小限の起動処理（実装済み）

- [x] メインデータベースのみ復元とマイグレーション（`scripts/start_app.sh`）
- [x] Railsサーバー起動
- [x] ヘルスチェックエンドポイントの最適化（`app/controllers/health_controller.rb`）

### ✅ Phase 2: バックグラウンド処理（実装済み）

- [x] キュー/キャッシュデータベースの復元とマイグレーションをバックグラウンド実行
- [x] agrr daemon起動をバックグラウンド実行
- [x] Litestream replicate開始をバックグラウンド実行
- [x] Solid Queue worker起動をバックグラウンド実行

### ✅ Phase 3: エラーハンドリングと監視（実装済み）

- [x] バックグラウンド処理のエラーハンドリング（基本的な実装）
- [x] マイグレーション状態の監視（`app/jobs/monitor_migration_status_job.rb`）
- [x] 起動時間の計測とログ記録（`scripts/start_app.sh`に追加）

### ✅ Phase 4: テスト（実装済み）

- [x] ヘルスチェックの動作確認（`test/controllers/health_controller_test.rb`）
- [x] マイグレーション状態監視ジョブのテスト（`test/jobs/monitor_migration_status_job_test.rb`）
- [x] バックグラウンド処理の動作確認（`test/integration/startup_background_processing_test.rb`）
- [x] エラーケースのテスト（各テストファイルに含まれる）

## 実装詳細

### 起動スクリプトの最適化（`scripts/start_app.sh`）

#### Phase 1: 最小限の起動処理（同期的に実行）

1. **メインデータベースの復元**
   ```bash
   litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production.sqlite3
   ```

2. **メインデータベースのマイグレーション**
   ```bash
   bundle exec rails db:migrate:primary
   ```

#### Phase 2: バックグラウンド処理（非同期実行）

`background_init()` 関数内で以下を実行：

1. **キュー/キャッシュデータベースの復元**
   - キューデータベース: `/tmp/production_queue.sqlite3`
   - キャッシュデータベース: `/tmp/production_cache.sqlite3`

2. **キュー/キャッシュデータベースのマイグレーション**
   ```bash
   bundle exec rails db:migrate:queue
   bundle exec rails db:migrate:cache
   ```

3. **agrr daemon起動**（オプション）
   - `USE_AGRR_DAEMON=true` の場合のみ実行

#### Phase 3: サーバー起動

1. **Litestream replication開始**（バックグラウンド）
2. **Solid Queue worker起動**（バックグラウンド）
3. **Railsサーバー起動**（フォアグラウンド - メインプロセス）

### 注意点

#### 1. マイグレーションコマンド

Rails 8では、複数のデータベースに対して個別にマイグレーションを実行できます：

- `db:migrate:primary` - メインデータベース
- `db:migrate:queue` - キューデータベース
- `db:migrate:cache` - キャッシュデータベース

#### 2. Solid Queue workerの起動タイミング

Solid Queue workerはキューデータベースが利用可能になるまで待機する必要があります。現在の実装では、workerを起動してからバックグラウンドでキューデータベースを復元・マイグレーションしていますが、workerがエラーになる可能性があります。

**対策案**:
- workerの起動を遅延させる（キューデータベースの準備完了を待つ）
- または、workerのエラーハンドリングを改善する

#### 3. ヘルスチェックエンドポイント

現在、`/up` エンドポイントはRails 8の標準ヘルスチェック（`rails/health#show`）を使用しています。これはデータベース接続を確認する可能性があります。

**推奨**: メインデータベースのみを確認する軽量なヘルスチェックエンドポイントを作成するか、標準のヘルスチェックがメインデータベースのみを確認するように設定する。

## 今後の改善案

### 1. ヘルスチェックエンドポイントの最適化

メインデータベースのみを確認する軽量なヘルスチェックエンドポイントを作成：

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def show
    # メインデータベースのみ確認
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: 'ok', timestamp: Time.current }
  rescue => e
    render json: { status: 'error', error: e.message }, status: :service_unavailable
  end
end
```

### 2. マイグレーション状態の監視

バックグラウンド処理のマイグレーション状態を監視するジョブを作成：

```ruby
# app/jobs/monitor_migration_status_job.rb
class MonitorMigrationStatusJob < ApplicationJob
  def perform
    # マイグレーション状態を確認
    # エラーがあればアラートを送信
  end
end
```

### 3. 起動時間の計測

起動時間を計測してログに記録：

```bash
START_TIME=$(date +%s)
# ... 起動処理 ...
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Startup completed in ${DURATION} seconds"
```

## 期待される効果

- **起動時間**: 現在の50%以下に短縮（データベース復元とマイグレーションの並列化/遅延実行により）
- **可用性**: メインデータベースが利用可能になれば、基本的な機能が利用可能
- **リソース効率**: 不要な処理を遅延実行することで、起動時のリソース使用量を削減

## 参考資料

- [Cloud Run 起動時間の最適化](https://cloud.google.com/run/docs/tips/general)
- [Rails 起動時間の最適化](https://guides.rubyonrails.org/performance_testing.html)
- [Litestream ドキュメント](https://litestream.io/)

