# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      # 気象データ取得の intrinsic 前提（I/O なし）。
      module FieldCultivationClimatePreconditionsPolicy
        module_function

        def missing_weather_location?(weather_location_present:)
          !weather_location_present
        end

        def missing_cultivation_period?(start_date:, completion_date:)
          start_date.nil? || completion_date.nil?
        end
      end
    end
  end
end
