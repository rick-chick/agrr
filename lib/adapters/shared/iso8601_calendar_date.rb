# frozen_string_literal: true

module Adapters
  module Shared
    # YYYY-MM-DD のみを検証してパースする（無効時は nil）。controller の ArgumentError rescue を避ける。
    module Iso8601CalendarDate
      module_function

      # @param logger [#warn] optional
      # @return [Date, nil]
      def parse(value, logger: nil)
        return nil if value.blank?

        s = value.to_s.strip
        m = /\A(\d{4})-(\d{2})-(\d{2})\z/.match(s)
        unless m
          logger&.warn "⚠️ Invalid ISO8601 calendar date (format): #{value.inspect}"
          return nil
        end

        y, mo, d = m.captures.map(&:to_i)
        unless Date.valid_date?(y, mo, d)
          logger&.warn "⚠️ Invalid ISO8601 calendar date (values): #{value.inspect}"
          return nil
        end

        Date.new(y, mo, d)
      end
    end
  end
end
