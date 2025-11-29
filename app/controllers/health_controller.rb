# frozen_string_literal: true

class HealthController < ApplicationController
  # ヘルスチェックは認証不要
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  # GET /up
  # メインデータベースのみを確認する軽量なヘルスチェック
  def show
    # メインデータベースの接続確認
    ActiveRecord::Base.connection.execute("SELECT 1")
    
    render json: { 
      status: 'ok', 
      timestamp: Time.current.iso8601,
      database: 'primary'
    }, status: :ok
  rescue => e
    Rails.logger.error "Health check failed: #{e.message}"
    render json: { 
      status: 'error', 
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end

