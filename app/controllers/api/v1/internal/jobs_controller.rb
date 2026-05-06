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
            message: "Weather update jobs enqueued",
            timestamp: Time.current.iso8601
          }
          # Application edge 3（インフラ・投入境界）
        rescue ActiveJob::EnqueueError, ActiveRecord::ActiveRecordError => e
          Rails.logger.error "❌ [Scheduler] Failed to trigger weather update: #{e.message}"
          Rails.logger.error "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end

        private

        def authenticate_scheduler_request
          # 環境変数からトークンを取得
          expected_token = ENV["SCHEDULER_AUTH_TOKEN"]

          unless expected_token.present?
            Rails.logger.error "❌ [Scheduler] SCHEDULER_AUTH_TOKEN not configured"
            render json: { error: "Authentication not configured" }, status: :service_unavailable
            return
          end

          # リクエストヘッダーまたはパラメータからトークンを取得
          provided_token = request.headers["X-Scheduler-Token"] ||
                          request.headers["Authorization"]&.gsub(/^Bearer /, "") ||
                          params[:token]

          unless provided_token.present?
            Rails.logger.warn "⚠️ [Scheduler] Missing authentication token"
            render json: { error: "Missing authentication token" }, status: :unauthorized
            return
          end

          # トークンを比較（タイミング攻撃対策のため secure_compare を使用）
          unless ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
            Rails.logger.warn "⚠️ [Scheduler] Invalid authentication token"
            render json: { error: "Invalid authentication token" }, status: :forbidden
            nil
          end
        end
      end
    end
  end
end
