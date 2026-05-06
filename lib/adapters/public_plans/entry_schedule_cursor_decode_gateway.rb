# frozen_string_literal: true

require "base64"
require "json"

module Adapters
  module PublicPlans
    # entry_schedule の cursor（Base64 JSON）デコード。失敗時は nil。
    class EntryScheduleCursorDecodeGateway
      def decode(raw)
        return nil if raw.blank?

        decoded = Base64.urlsafe_decode64(raw.to_s)
        hash = JSON.parse(decoded)
        int_offset(hash.fetch("o"))
      rescue ArgumentError, JSON::ParserError, TypeError, KeyError
        nil
      end

      private

      def int_offset(o)
        case o
        when Integer
          o
        when String
          Integer(o, 10)
        else
          raise TypeError, "cursor offset must be integer-coercible"
        end
      end
    end
  end
end
