# frozen_string_literal: true

module Adapters
  module Shared
    # Time.iso8601 を境界に閉じ込め、controller の rescue を避ける。
    module Iso8601TimeParse
      module_function

      # @return [ActiveSupport::TimeWithZone, nil]
      def parse_in_application_zone(string)
        return nil unless string.is_a?(String) && string.present?

        Time.iso8601(string).in_time_zone(Time.zone)
      rescue ArgumentError
        nil
      end
    end
  end
end
