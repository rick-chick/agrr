# frozen_string_literal: true

module Adapters
  module Shared
    module Ports
      # Rails.logger への一方向出力アダプタ（Infrastructure Port 実装）。
      # interface: Domain::Shared::Ports::LoggerPort
      class RailsLoggerAdapter
        include Domain::Shared::Ports::LoggerPort

        def debug(message, progname = nil)
          Rails.logger.debug(message)
        end

        def info(message, progname = nil)
          Rails.logger.info(message)
        end

        def warn(message, progname = nil)
          Rails.logger.warn(message)
        end

        def error(message, progname = nil)
          Rails.logger.error(message)
        end

        def fatal(message, progname = nil)
          Rails.logger.fatal(message)
        end

        def unknown(message, progname = nil)
          Rails.logger.unknown(message)
        end
      end
    end
  end
end
