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
    msg = e.message.to_s
    if msg.include?('unable to open database file') || msg.include?('database is locked') || msg.include?('no such table')
      Rails.logger.warn "Health check: DB bootstrap in progress or not ready (#{msg})"
    else
      Rails.logger.error "Health check failed: #{msg}"
    end
    render json: {
      status: 'error',
      error: msg,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end

