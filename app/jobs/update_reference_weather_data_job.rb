# frozen_string_literal: true

# 参照農場の天気データを定期的に更新するジョブ
#
# 用途:
#   - 毎日実行し、参照農場の最新の天気データを取得
#   - 過去7日分のデータを取得して既存データを更新
#
# 実行方法:
#   - config/recurring.yml で定期実行設定（推奨: 毎日午前3時）
#   - 手動実行: UpdateReferenceWeatherDataJob.perform_later
#
# エラーハンドリング:
#   - データベース接続エラー: 10秒待機して5回までリトライ
#   - その他のエラー: 指数バックオフで3回までリトライ
#   - レコードが見つからない: リトライせず破棄
#
class UpdateReferenceWeatherDataJob < ApplicationJob
  queue_as :default

  # 定数定義
  WEATHER_DATA_LOOKBACK_DAYS = 7  # 過去何日分のデータを取得するか
  API_INTERVAL_SECONDS = 1.0      # API負荷軽減のための間隔（秒）

  # レコードが見つからない場合はリトライしない
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.warn "⚠️  [UpdateReferenceWeatherDataJob] レコードが見つかりません（破棄）"
    Rails.logger.warn "   #{exception.message}"
  end

  # データベース接続エラーは短い間隔でリトライ
  # より具体的なエラーを先に定義することで、優先的にマッチする
  retry_on ActiveRecord::ConnectionNotEstablished,
           wait: 10.seconds,
           attempts: 5 do |job, exception|
    Rails.logger.error "❌ [UpdateReferenceWeatherDataJob] DB接続エラー（最終リトライ失敗）"
    Rails.logger.error "   エラー: #{exception.message}"
  end

  # その他の一般的なエラーは指数バックオフでリトライ（3秒、9秒、27秒）
  # ActiveRecord::ConnectionNotEstablishedは上で処理されるため、ここには来ない
  retry_on StandardError,
           wait: ->(executions) { 3 * (3 ** executions) },
           attempts: 3 do |job, exception|
    # 最終リトライ失敗時のログ
    Rails.logger.error "❌ [UpdateReferenceWeatherDataJob] すべてのリトライが失敗しました"
    Rails.logger.error "   エラー: #{exception.class} - #{exception.message}"
    Rails.logger.error "   Backtrace: #{exception.backtrace.first(5).join("\n   ")}"
    
    # 将来的にはここで管理者通知を実装
    # AdminNotifier.job_failed(job.class.name, exception).deliver_later
  end

  def perform
    start_time = Time.current
    
    Rails.logger.info "🌤️  [UpdateReferenceWeatherDataJob] 参照農場の天気データ更新を開始"

    # 全参照農場を取得
    reference_farms = Farm.reference.where.not(latitude: nil, longitude: nil)

    if reference_farms.empty?
      Rails.logger.info "⏭️  [UpdateReferenceWeatherDataJob] 参照農場が見つかりませんでした"
      return
    end

    Rails.logger.info "📋 [UpdateReferenceWeatherDataJob] 参照農場#{reference_farms.count}件を発見"

    # タイムゾーンを明示的に指定して日付を取得
    # 利用可能な最新データの日付までを取得（未来の日付は取得できない）
    start_date = Time.zone.today - WEATHER_DATA_LOOKBACK_DAYS.days
    end_date = Time.zone.today

    # 2025年までのデータのみ取得可能（2026年データはまだ利用できない）
    # 実際のデータ可用性を考慮してend_dateを制限
    max_available_year = 2025
    if end_date.year > max_available_year
      end_date = Date.new(max_available_year, 12, 31)
      start_date = [start_date, Date.new(max_available_year, 1, 1)].max
    end

    Rails.logger.info "📅 [UpdateReferenceWeatherDataJob] 取得期間: #{start_date} 〜 #{end_date}"

    # 各参照農場の天気データ取得ジョブをエンキュー
    reference_farms.each_with_index do |farm, index|
      # API負荷軽減のため、設定した間隔でジョブを実行
      FetchWeatherDataJob.set(wait: index * API_INTERVAL_SECONDS.seconds).perform_later(
        farm_id: farm.id,
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: start_date,
        end_date: end_date
      )
      
      Rails.logger.info "✅ [UpdateReferenceWeatherDataJob] [Farm##{farm.id}] '#{farm.name}' をエンキュー"
    end

    elapsed_time = (Time.current - start_time).round(2)
    Rails.logger.info "🎉 [UpdateReferenceWeatherDataJob] 完了: #{reference_farms.count}件（#{elapsed_time}秒）"
  end
end

