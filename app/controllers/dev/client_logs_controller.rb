# frozen_string_literal: true

module Dev
  # 開発環境専用: クライアント側のJavaScriptログを受信するコントローラー
  class ClientLogsController < ApplicationController
    # CSRF保護をスキップ（開発環境のみ）
    skip_before_action :verify_authenticity_token, only: [:create]

    # ログを受信して Rails.logger に出力
    def create
      return head :forbidden unless Rails.env.development?

      # バッチリクエストの場合
      if params[:batch] == true || params[:batch] == 'true'
        process_batch_logs
      else
        process_single_log
      end

      head :ok
    rescue => e
      Rails.logger.error("[CLIENT LOGGER ERROR] Failed to process client log: #{e.message}")
      head :internal_server_error
    end

    private

    # バッチログを処理
    def process_batch_logs
      logs = params[:logs] || []
      return if logs.empty?

      puts "\n[CLIENT JS BATCH] Received #{logs.length} logs"
      
      logs.each do |log_data|
        output_log(log_data)
      end
    end

    # 単一ログを処理
    def process_single_log
      log_data = params.permit(:level, :message, :stack_trace, :url, :user_agent, :timestamp)
      output_log(log_data)
    end

    # ログを出力
    def output_log(log_data)
      level = log_data[:level] || log_data['level'] || 'log'
      message = log_data[:message] || log_data['message'] || '(empty message)'
      url = log_data[:url] || log_data['url'] || '(unknown url)'
      timestamp = log_data[:timestamp] || log_data['timestamp'] || Time.current.iso8601
      stack_trace = log_data[:stack_trace] || log_data['stack_trace']

      # ログレベルに応じて出力
      formatted_message = "[CLIENT JS #{level.upcase}] #{timestamp} | #{url}\n#{message}"
      
      if stack_trace.present?
        formatted_message += "\nStack Trace:\n#{stack_trace}"
      end

      # 標準出力にも出力（docker compose logsで確認できるように）
      puts "\n#{formatted_message}\n"

      case level
      when 'error'
        Rails.logger.error(formatted_message)
      when 'warn'
        Rails.logger.warn(formatted_message)
      when 'info'
        Rails.logger.info(formatted_message)
      when 'debug'
        Rails.logger.debug(formatted_message)
      else
        Rails.logger.info(formatted_message)
      end
    end
  end
end

