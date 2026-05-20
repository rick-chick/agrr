# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      class SqlLikeActiveRecordGateway
        include Domain::Shared::Ports::SqlLikeSanitizePort

        def sanitize_like(term)
          ActiveRecord::Base.sanitize_sql_like(term.to_s)
        end
      end
    end
  end
end
