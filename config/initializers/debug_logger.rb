# frozen_string_literal: true

if ENV["AGRR_DEBUG"].to_s == "1"
  require "fileutils"

  debug_dir = Rails.root.join("tmp", "debug")
  FileUtils.mkdir_p(debug_dir)

  debug_log_path = debug_dir.join("debug.log")

  # 追加のデバッグロガーを作成し、既存のRails.loggerにブロードキャスト
  debug_logger = ActiveSupport::Logger.new(debug_log_path)
  debug_logger.level = Logger::DEBUG

  Rails.logger.level = Logger::DEBUG if Rails.logger.respond_to?(:level=)
  Rails.logger.extend(ActiveSupport::Logger.broadcast(debug_logger))

  Rails.logger.info "🛠  AGRR_DEBUG enabled. Broadcasting DEBUG logs to #{debug_log_path}"
end
