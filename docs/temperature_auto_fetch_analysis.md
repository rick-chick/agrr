# 温度データ自動取得の実装分析

## 概要

本ドキュメントは、温度データの自動取得機能をGCP Cloud Scheduler + APIエンドポイント方式で実装するための分析と実装計画です。

### 実装方針
- **方式**: GCP Cloud Scheduler + APIエンドポイント
- **目的**: 参照農場と通常農場の温度データを定期的に自動更新
- **実行頻度**: 毎日（参照農場: 午前3時、通常農場: 午前4時）

### 実装の流れ
1. 通常農場の更新ジョブ作成（`UpdateUserFarmsWeatherDataJob`）
2. APIエンドポイントの実装（`JobsController`）
3. GCP Cloud Schedulerの設定
4. 監視とエラーハンドリング

## 現状の実装状況

### 1. 温度データ取得の仕組み

#### 1.1 データ取得ジョブ
- **`FetchWeatherDataJob`** (`app/jobs/fetch_weather_data_job.rb`)
  - 緯度経度と期間を指定して天気データ（温度含む）を取得
  - `Agrr::WeatherGateway`を使用して外部APIから取得
  - 取得したデータを`WeatherDatum`テーブルに保存
  - 温度データ: `temperature_max`, `temperature_min`, `temperature_mean`

#### 1.2 データ保存先
- **`WeatherLocation`** (`app/models/weather_location.rb`)
  - 緯度経度ごとに1つのレコード
  - 複数の`Farm`が同じ`WeatherLocation`を参照可能
  - `has_many :weather_data`で`WeatherDatum`と関連
  - `latest_weather_date`: 最新の天気データの日付を取得可能

- **`WeatherDatum`** (テーブル)
  - `weather_location_id`と`date`でユニーク
  - 温度データ: `temperature_max`, `temperature_min`, `temperature_mean`
  - その他: `precipitation`, `sunshine_hours`, `wind_speed`, `weather_code`

### 2. 現在の自動取得の実装

#### 2.1 参照農場（`is_reference: true`）
- **ジョブ**: `UpdateReferenceWeatherDataJob` (`app/jobs/update_reference_weather_data_job.rb`)
  - 過去7日分のデータを取得
  - 全参照農場に対して`FetchWeatherDataJob`をエンキュー
  - **問題点**: `config/recurring.yml`に設定されていない（手動実行のみ）

#### 2.2 通常の農場（`is_reference: false`）
- **農場作成時**: `Farm#enqueue_weather_data_fetch` (`app/models/farm.rb:205`)
  - 2000年から現在までのデータを5年ブロックで取得
  - 農場作成時のみ実行（`after_create_commit`）
  - **問題点**: 作成後の自動更新がない

#### 2.3 緯度経度変更時
- **`Farm#enqueue_weather_data_fetch_if_coordinates_changed`** (`app/models/farm.rb:197`)
  - 緯度経度が変更された場合に再取得
  - `after_update_commit`で実行

### 3. 定期実行の仕組み

#### 3.1 Solid Queue Recurring Tasks
- **設定ファイル**: `config/recurring.yml`
  - 現在は`clear_solid_queue_finished_jobs`のみ設定
  - `UpdateReferenceWeatherDataJob`は設定されていない

#### 3.2 定期実行の設定方法
```yaml
production:
  update_reference_weather_data:
    class: UpdateReferenceWeatherDataJob
    schedule: at 3am every day
```

## 自動取得が必要な箇所

### 1. 参照農場の定期更新（優先度: 高）
**現状**: ジョブは実装済みだが、定期実行が設定されていない

**必要な実装**:
- `config/recurring.yml`に`UpdateReferenceWeatherDataJob`を追加
- 毎日実行（推奨: 午前3時）
- 過去7日分のデータを取得して既存データを更新

**実装箇所**:
- `config/recurring.yml`: 定期実行の設定を追加

### 2. 通常の農場の最新データ更新（優先度: 高）
**現状**: 農場作成時のみ取得。その後は自動更新されない

**必要な実装**:
- 新規ジョブ: `UpdateUserFarmsWeatherDataJob`を作成
- 全通常農場（`is_reference: false`）に対して最新データを取得
- 各農場の`WeatherLocation#latest_weather_date`を確認
- 最新日付から今日までのデータを取得（欠損分を補完）

**実装箇所**:
- `app/jobs/update_user_farms_weather_data_job.rb`: 新規作成
- `config/recurring.yml`: 定期実行の設定を追加

**実装方針**:
```ruby
# frozen_string_literal: true

class UpdateUserFarmsWeatherDataJob < ApplicationJob
  queue_as :default
  
  # 定数定義
  DEFAULT_LOOKBACK_DAYS = 7  # 最新日付がない場合の過去日数
  API_INTERVAL_SECONDS = 1.0  # API負荷軽減のための間隔（秒）
  
  # エラーハンドリング（UpdateReferenceWeatherDataJobと同様）
  retry_on StandardError,
           wait: ->(executions) { 3 * (3 ** executions) },
           attempts: 3 do |job, exception|
    Rails.logger.error "❌ [UpdateUserFarmsWeatherDataJob] すべてのリトライが失敗しました"
    Rails.logger.error "   エラー: #{exception.class} - #{exception.message}"
  end
  
  def perform
    start_time = Time.current
    
    Rails.logger.info "🌤️  [UpdateUserFarmsWeatherDataJob] 通常農場の天気データ更新を開始"
    
    # 全通常農場を取得（weather_locationが設定されているもののみ）
    user_farms = Farm.user_owned.where.not(weather_location_id: nil)
    
    if user_farms.empty?
      Rails.logger.info "⏭️  [UpdateUserFarmsWeatherDataJob] 通常農場が見つかりませんでした"
      return
    end
    
    Rails.logger.info "📋 [UpdateUserFarmsWeatherDataJob] 通常農場#{user_farms.count}件を発見"
    
    # 各農場の最新データを取得
    user_farms.find_each.with_index do |farm, index|
      weather_location = farm.weather_location
      latest_date = weather_location.latest_weather_date
      
      # 最新日付から今日までのデータを取得
      if latest_date
        start_date = latest_date + 1.day
        # 既に最新の場合はスキップ
        if start_date > Date.today
          Rails.logger.debug "⏭️  [UpdateUserFarmsWeatherDataJob] [Farm##{farm.id}] Already up to date (latest: #{latest_date})"
          next
        end
      else
        # 最新日付がない場合は過去7日分を取得
        start_date = Date.today - DEFAULT_LOOKBACK_DAYS.days
      end
      
      end_date = Date.today
      
      # API負荷軽減のため、設定した間隔でジョブを実行
      FetchWeatherDataJob.set(wait: index * API_INTERVAL_SECONDS.seconds).perform_later(
        farm_id: farm.id,
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: start_date,
        end_date: end_date
      )
      
      Rails.logger.info "✅ [UpdateUserFarmsWeatherDataJob] [Farm##{farm.id}] '#{farm.name}' をエンキュー (#{start_date} 〜 #{end_date})"
    end
    
    elapsed_time = (Time.current - start_time).round(2)
    Rails.logger.info "🎉 [UpdateUserFarmsWeatherDataJob] 完了: #{user_farms.count}件（#{elapsed_time}秒）"
  end
end
```

### 3. データ欠損の補完（優先度: 中）
**現状**: データ取得時に8割以上のデータがあればスキップするが、欠損分の補完は行わない

**必要な実装**:
- 既存データの欠損日を検出
- 欠損期間のデータを取得

**実装箇所**:
- `FetchWeatherDataJob`の改善、または新規ジョブ

### 4. 予測データの更新（優先度: 低）
**現状**: 予測データは24時間以上経過した場合に再予測されるが、実データの更新に依存

**必要な実装**:
- 実データ更新後に予測データも更新する仕組み（既存の実装で対応可能）

## GCPでの定期実行の実装方針

**採用方式: GCP Cloud Scheduler + APIエンドポイント**

### 採用理由
- Cloud Runのインスタンスを常時起動する必要がない
- より細かい制御が可能
- コスト削減の可能性
- GCPの標準的な定期実行方式

### 実装方法

#### 1. 新規APIエンドポイントの作成

**コントローラー**: `app/controllers/api/v1/internal/jobs_controller.rb`（新規作成）

```ruby
# frozen_string_literal: true

module Api
  module V1
    module Internal
      # GCP Cloud Schedulerからの定期実行リクエストを受け付けるコントローラー
      class JobsController < ApplicationController
        skip_before_action :verify_authenticity_token
        skip_before_action :authenticate_user!
        
        before_action :authenticate_scheduler_request
        
        # POST /api/v1/internal/jobs/trigger_weather_update
        # 参照農場と通常農場の天気データを更新
        def trigger_weather_update
          Rails.logger.info "🌤️ [Scheduler] Weather update triggered via API"
          
          # 参照農場の更新
          UpdateReferenceWeatherDataJob.perform_later
          
          # 通常農場の更新
          UpdateUserFarmsWeatherDataJob.perform_later
          
          render json: {
            success: true,
            message: 'Weather update jobs enqueued',
            timestamp: Time.current.iso8601
          }
        rescue => e
          Rails.logger.error "❌ [Scheduler] Failed to trigger weather update: #{e.message}"
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
        
        private
        
        def authenticate_scheduler_request
          # 環境変数からトークンを取得
          expected_token = ENV['SCHEDULER_AUTH_TOKEN']
          
          unless expected_token.present?
            Rails.logger.error "❌ [Scheduler] SCHEDULER_AUTH_TOKEN not configured"
            render json: { error: 'Authentication not configured' }, status: :service_unavailable
            return
          end
          
          # リクエストヘッダーまたはパラメータからトークンを取得
          provided_token = request.headers['X-Scheduler-Token'] || 
                          request.headers['Authorization']&.gsub(/^Bearer /, '') ||
                          params[:token]
          
          unless provided_token.present?
            Rails.logger.warn "⚠️ [Scheduler] Missing authentication token"
            render json: { error: 'Missing authentication token' }, status: :unauthorized
            return
          end
          
          # トークンを比較（タイミング攻撃対策のため secure_compare を使用）
          unless ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
            Rails.logger.warn "⚠️ [Scheduler] Invalid authentication token"
            render json: { error: 'Invalid authentication token' }, status: :forbidden
            return
          end
        end
      end
    end
  end
end
```

**ルーティング**: `config/routes.rb`に追加

```ruby
namespace :api do
  namespace :v1 do
    namespace :internal do
      resources :jobs, only: [] do
        collection do
          post 'trigger_weather_update'
        end
      end
    end
  end
end
```

#### 2. 環境変数の設定

**環境変数**: `SCHEDULER_AUTH_TOKEN`
- 本番環境用の設定ファイル（`.env.gcp`）に追加
- ランダムな文字列を生成して設定

```bash
# トークン生成例
openssl rand -hex 32
```

#### 3. GCP Cloud Schedulerの設定

**前提条件**:
- GCPプロジェクトへの適切な権限（Cloud Scheduler Admin）
- `gcloud` CLIのインストールと認証
- Cloud RunサービスのURL

**設定手順**:

1. **環境変数の準備**
   ```bash
   # プロジェクトIDとリージョンを設定（.env.gcpから取得）
   PROJECT_ID="agrr-475323"  # 実際のプロジェクトIDに置き換え
   REGION="asia-northeast1"
   SERVICE_NAME="agrr-production"  # 実際のサービス名に置き換え
   
   # Cloud RunサービスのURLを取得
   SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
     --region=$REGION \
     --project=$PROJECT_ID \
     --format='value(status.url)')
   
   # スケジューラートークンを生成（既に設定済みの場合は使用）
   SCHEDULER_TOKEN=$(openssl rand -hex 32)
   ```

2. **Cloud Schedulerジョブの作成**
   ```bash
   # 参照農場の更新ジョブ（毎日午前3時）
   gcloud scheduler jobs create http update-reference-weather-data \
     --project=$PROJECT_ID \
     --location=$REGION \
     --schedule="0 3 * * *" \
     --uri="$SERVICE_URL/api/v1/internal/jobs/trigger_weather_update" \
     --http-method=POST \
     --headers="X-Scheduler-Token=$SCHEDULER_TOKEN" \
     --time-zone="Asia/Tokyo" \
     --description="Daily weather data update for reference farms" \
     --attempt-deadline=600s
   
   # 通常農場の更新ジョブ（毎日午前4時）
   gcloud scheduler jobs create http update-user-farms-weather-data \
     --project=$PROJECT_ID \
     --location=$REGION \
     --schedule="0 4 * * *" \
     --uri="$SERVICE_URL/api/v1/internal/jobs/trigger_weather_update" \
     --http-method=POST \
     --headers="X-Scheduler-Token=$SCHEDULER_TOKEN" \
     --time-zone="Asia/Tokyo" \
     --description="Daily weather data update for user farms" \
     --attempt-deadline=600s
   ```

3. **ジョブの確認**
   ```bash
   # 作成されたジョブを確認
   gcloud scheduler jobs list --location=$REGION --project=$PROJECT_ID
   
   # 特定のジョブの詳細を確認
   gcloud scheduler jobs describe update-reference-weather-data \
     --location=$REGION \
     --project=$PROJECT_ID
   ```

4. **手動実行でテスト**
   ```bash
   # ジョブを手動で実行してテスト
   gcloud scheduler jobs run update-reference-weather-data \
     --location=$REGION \
     --project=$PROJECT_ID
   ```

5. **ジョブの更新（必要に応じて）**
   ```bash
   # スケジュールを変更する場合
   gcloud scheduler jobs update http update-reference-weather-data \
     --location=$REGION \
     --project=$PROJECT_ID \
     --schedule="0 3 * * *"
   ```

6. **ジョブの削除（必要に応じて）**
   ```bash
   # ジョブを削除する場合
   gcloud scheduler jobs delete update-reference-weather-data \
     --location=$REGION \
     --project=$PROJECT_ID
   ```

**スケジュール設定例**:
- 毎日午前3時: `0 3 * * *`
- 毎日午前4時: `0 4 * * *`
- 6時間ごと: `0 */6 * * *`
- 毎時: `0 * * * *`
- Cron形式の詳細: https://cloud.google.com/scheduler/docs/configuring/cron-job-schedules

**注意事項**:
- `--attempt-deadline`: ジョブのタイムアウト（秒）。Cloud Runのタイムアウト（600秒）と整合させる
- `--time-zone`: タイムゾーンを明示的に指定（デフォルトはUTC）
- トークンは環境変数またはSecret Managerで管理

#### 4. 既存のSolid Queue Recurring Tasksとの関係

- **開発環境・テスト環境**: 引き続き`config/recurring.yml`を使用可能（オプション）
- **本番環境**: GCP Cloud Schedulerを使用
- 環境変数で切り替え可能な実装も検討可能

## 実装順序

### Phase 1: 通常農場の更新ジョブ作成
1. `UpdateUserFarmsWeatherDataJob`を作成
   - `app/jobs/update_user_farms_weather_data_job.rb`（新規）
   - 全通常農場の最新データを取得
2. テストを作成
   - `test/jobs/update_user_farms_weather_data_job_test.rb`（新規）
3. 動作確認（手動実行）

### Phase 2: APIエンドポイントの実装
1. `JobsController`を作成
   - `app/controllers/api/v1/internal/jobs_controller.rb`（新規）
   - 認証ロジックの実装
2. ルーティングを追加
   - `config/routes.rb`に追加
3. テストを作成
   - `test/controllers/api/v1/internal/jobs_controller_test.rb`（新規）
4. 環境変数の設定
   - `.env.gcp`に`SCHEDULER_AUTH_TOKEN`を追加
   - `env.gcp.example`にも追加

### Phase 3: GCP Cloud Schedulerの設定
1. 本番環境の環境変数を設定
   - Cloud Runサービスの環境変数として`SCHEDULER_AUTH_TOKEN`を設定
   - またはGCP Secret Managerを使用（推奨）
   ```bash
   # 環境変数として設定する場合
   gcloud run services update $SERVICE_NAME \
     --region=$REGION \
     --project=$PROJECT_ID \
     --update-env-vars="SCHEDULER_AUTH_TOKEN=$SCHEDULER_TOKEN"
   
   # Secret Managerを使用する場合（推奨）
   # 1. Secretを作成
   echo -n "$SCHEDULER_TOKEN" | gcloud secrets create scheduler-auth-token \
     --data-file=- \
     --project=$PROJECT_ID
   
   # 2. Cloud Runサービスアカウントに権限を付与
   gcloud secrets add-iam-policy-binding scheduler-auth-token \
     --member="serviceAccount:cloud-run-agrr@$PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/secretmanager.secretAccessor" \
     --project=$PROJECT_ID
   
   # 3. Cloud RunサービスにSecretをマウント
   gcloud run services update $SERVICE_NAME \
     --region=$REGION \
     --project=$PROJECT_ID \
     --update-secrets="SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest"
   ```
2. Cloud Schedulerジョブを作成
   - `gcloud`コマンドでジョブを作成（上記の設定手順を参照）
3. 動作確認
   - 手動でジョブを実行して確認
   - Cloud Loggingでログを確認
   - ジョブの実行履歴を確認

### Phase 4: 監視とエラーハンドリング
1. ログ監視の設定
   - Cloud Loggingでの監視
2. エラー通知の実装（将来的に）
   - 失敗時の通知機能

## 実装時の注意点

### 1. セキュリティ
- **認証トークン**: 強力なランダム文字列を使用（32文字以上推奨）
- **HTTPS必須**: Cloud SchedulerからHTTPSでリクエスト
- **タイミング攻撃対策**: `ActiveSupport::SecurityUtils.secure_compare`を使用
- **環境変数の管理**: Secret Managerの使用を推奨

### 2. API負荷軽減
- ジョブ間隔を適切に設定（`API_INTERVAL_SECONDS`）
- バッチ処理で複数農場を一度に処理
- レート制限の考慮

### 3. エラーハンドリング
- リトライロジックの実装（既存ジョブに実装済み）
- エラーログの記録
- Cloud Loggingでの監視
- 管理者への通知（将来的に）

### 4. データ整合性
- `WeatherLocation`の共有を考慮
- 同じ緯度経度の農場は同じ`WeatherLocation`を参照
- 重複取得を避ける（既存の`FetchWeatherDataJob`で実装済み）

### 5. パフォーマンス
- 大量の農場がある場合の処理時間
- データベースクエリの最適化
- インデックスの確認
- `find_each`を使用してメモリ効率を向上

### 6. Cloud Schedulerの設定
- タイムゾーンの設定（`--time-zone="Asia/Tokyo"`）
- リトライ設定（デフォルトで3回リトライ）
- タイムアウト設定（Cloud Runのタイムアウトと整合）

### 7. テスト
- コントローラーのテスト（認証のテスト含む）
- ジョブのテスト
- 統合テスト（APIエンドポイントからジョブ実行まで）

## 関連ファイル一覧

### 既存ファイル
- `app/jobs/fetch_weather_data_job.rb`: 天気データ取得ジョブ
- `app/jobs/update_reference_weather_data_job.rb`: 参照農場更新ジョブ
- `app/models/farm.rb`: 農場モデル（作成時の自動取得）
- `app/models/weather_location.rb`: 天気データの保存先
- `app/gateways/agrr/weather_gateway.rb`: 外部APIゲートウェイ
- `config/recurring.yml`: 定期実行設定（現在は未設定）

### 新規作成が必要なファイル
- `app/jobs/update_user_farms_weather_data_job.rb`: 通常農場更新ジョブ
- `app/controllers/api/v1/internal/jobs_controller.rb`: スケジューラー用APIコントローラー
- `test/jobs/update_user_farms_weather_data_job_test.rb`: ジョブのテスト
- `test/controllers/api/v1/internal/jobs_controller_test.rb`: コントローラーのテスト

### 修正が必要なファイル
- `config/routes.rb`: APIエンドポイントのルーティングを追加
- `.env.gcp`: `SCHEDULER_AUTH_TOKEN`環境変数を追加
- `env.gcp.example`: 環境変数の例を追加

### GCP設定
- Cloud Schedulerジョブの作成（`gcloud`コマンド）
- 環境変数の設定（Secret Managerまたは環境変数）

