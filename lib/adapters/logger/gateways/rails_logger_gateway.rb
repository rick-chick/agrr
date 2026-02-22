# frozen_string_literal: true

module Adapters
  module Logger
    module Gateways
      class RailsLoggerGateway < Domain::Logger::Gateways::LoggerGateway
        def debug(message, progname = nil)
          Rails.logger.debug(message, progname)
        end

        def info(message, progname = nil)
          Rails.logger.info(message, progname)
        end

        def warn(message, progname = nil)
          Rails.logger.warn(message, progname)
        end

        def error(message, progname = nil)
          Rails.logger.error(message, progname)
        end

        def fatal(message, progname = nil)
          Rails.logger.fatal(message, progname)
        end

        def unknown(message, progname = nil)
          Rails.logger.unknown(message, progname)
        end
      end
    end
  end
end