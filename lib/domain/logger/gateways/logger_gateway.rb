# frozen_string_literal: true

module Domain
  module Logger
    module Gateways
      class LoggerGateway
        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def debug(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement debug"
        end

        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def info(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement info"
        end

        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def warn(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement warn"
        end

        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def error(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement error"
        end

        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def fatal(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement fatal"
        end

        # @param message [String] ログメッセージ
        # @param progname [String, nil] プログラム名（オプション）
        def unknown(message, progname = nil)
          raise NotImplementedError, "Subclasses must implement unknown"
        end
      end
    end
  end
end