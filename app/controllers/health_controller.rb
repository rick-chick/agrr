# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # SELECT 1 による接続・クエリで起きうる例外のみを 503 に落とす（ARCHITECTURE.md Application edge 3:
  # StandardError 一律の rescue は使わない）。それ以外は再 raise し、DB 以外の不具合は 500 で検知できる。
  HEALTH_DB_EXCEPTIONS = (
    [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::StatementInvalid
    ] + (defined?(SQLite3::Exception) ? [ SQLite3::Exception ] : [])
  ).freeze

  # GET /up
  # メインデータベースのみを確認する軽量なヘルスチェック
  def show
    # メインデータベースの接続確認
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: {
      status: "ok",
      timestamp: Time.current.iso8601,
      database: "primary"
    }, status: :ok
  rescue *HEALTH_DB_EXCEPTIONS => e
    msg = e.message.to_s
    if msg.include?("unable to open database file") || msg.include?("database is locked") || msg.include?("no such table")
      Rails.logger.warn "Health check: DB bootstrap in progress or not ready (#{msg})"
    else
      Rails.logger.error "Health check failed: #{msg}"
    end
    render json: {
      status: "error",
      error: msg,
      timestamp: Time.current.iso8601
    }, status: :service_unavailable
  end
end
