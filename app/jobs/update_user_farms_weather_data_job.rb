# frozen_string_literal: true

# 通常農場の天気データを定期的に更新するジョブ
#
# 用途:
#   - 毎日実行し、通常農場の最新の天気データを取得
#   - 各農場の最新データ日付から今日までのデータを取得（欠損分を補完）
#
# 実行方法:
#   - GCP Cloud SchedulerからAPIエンドポイント経由で実行（推奨: 毎日午前4時）
#   - 手動実行: UpdateUserFarmsWeatherDataJob.perform_later
#
# エラーハンドリング:
#   - データベース接続エラー: 10秒待機して5回までリトライ
#   - その他のエラー: 指数バックオフで3回までリトライ
#   - レコードが見つからない: リトライせず破棄
#
class UpdateUserFarmsWeatherDataJob < ApplicationJob
  queue_as :default

  # 定数定義
  DEFAULT_LOOKBACK_DAYS = 7  # 最新日付がない場合の過去日数
  API_INTERVAL_SECONDS = 1.0  # API負荷軽減のための間隔（秒）

  # レコードが見つからない場合はリトライしない
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.warn "⚠️  [UpdateUserFarmsWeatherDataJob] レコードが見つかりません（破棄）"
    Rails.logger.warn "   #{exception.message}"
  end

  # データベース接続エラーは短い間隔でリトライ
  # より具体的なエラーを先に定義することで、優先的にマッチする
  retry_on ActiveRecord::ConnectionNotEstablished,
           wait: 10.seconds,
           attempts: 5 do |job, exception|
    Rails.logger.error "❌ [UpdateUserFarmsWeatherDataJob] DB接続エラー（最終リトライ失敗）"
    Rails.logger.error "   エラー: #{exception.message}"
  end

  # その他の一般的なエラーは指数バックオフでリトライ（3秒、9秒、27秒）
  # ActiveRecord::ConnectionNotEstablishedは上で処理されるため、ここには来ない
  retry_on StandardError,
           wait: ->(executions) { 3 * (3 ** executions) },
           attempts: 3 do |job, exception|
    # 最終リトライ失敗時のログ
    Rails.logger.error "❌ [UpdateUserFarmsWeatherDataJob] すべてのリトライが失敗しました"
    Rails.logger.error "   エラー: #{exception.class} - #{exception.message}"
    Rails.logger.error "   Backtrace: #{exception.backtrace.first(5).join("\n   ")}"
    
    # 将来的にはここで管理者通知を実装
    # AdminNotifier.job_failed(job.class.name, exception).deliver_later
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
        if start_date > Time.zone.today
          Rails.logger.debug "⏭️  [UpdateUserFarmsWeatherDataJob] [Farm##{farm.id}] Already up to date (latest: #{latest_date})"
          next
        end
      else
        # 最新日付がない場合は過去7日分を取得
        start_date = Time.zone.today - DEFAULT_LOOKBACK_DAYS.days
      end
      
      end_date = Time.zone.today
      
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

