# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が Rails.logger を直接参照しないためのポート。
      # 実装は lib/adapters/logger/gateways/rails_logger_gateway.rb。
      # NOTE: Clean Architecture 純化のため、Controller (Composition Root) で
      # Adapter インスタンスを生成し Interactor へ DI する方式に段階移行中。
      # `.default` は移行未完了の Interactor 互換のため残置（移行完了後に削除）。
      module LoggerPort
        class << self
          def default
            @default ||= Adapters::Logger::Gateways::RailsLoggerGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def info(message)
          raise NotImplementedError, "#{self.class}#info"
        end

        def warn(message)
          raise NotImplementedError, "#{self.class}#warn"
        end

        def error(message)
          raise NotImplementedError, "#{self.class}#error"
        end

        def debug(message)
          raise NotImplementedError, "#{self.class}#debug"
        end
      end
    end
  end
end
