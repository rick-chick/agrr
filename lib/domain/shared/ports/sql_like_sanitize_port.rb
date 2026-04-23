# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # SQL LIKE 用エスケープ（実装は Adapter で ActiveRecord に委譲）
      module SqlLikeSanitizePort
        class << self
          def default
            @default ||= Adapters::Shared::Gateways::SqlLikeActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def sanitize_like(term)
          raise NotImplementedError, "#{self.class}#sanitize_like"
        end
      end
    end
  end
end
