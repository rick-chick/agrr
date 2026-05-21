# frozen_string_literal: true

module Domain
  module WeatherData
    # predicted_weather_data 等の入れ子を呼び出し元から切り離し、可能な範囲で不変にする
    module PayloadImmutable
      module_function

      def copy_and_deep_freeze(value)
        return nil if value.nil?

        copy = Domain::Shared.deep_dup(value)
        deep_freeze!(copy)
        copy
      end

      def deep_freeze!(obj)
        case obj
        when Hash
          obj.each_value { |v| deep_freeze!(v) }
        when Array
          obj.each { |e| deep_freeze!(e) }
        end
        obj.freeze
      end
    end
  end
end
