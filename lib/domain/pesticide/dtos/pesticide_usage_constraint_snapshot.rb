# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # HTML 表示用スナップショット（永続モデルをビューに渡さない）
      class PesticideUsageConstraintSnapshot
        attr_reader :min_temperature, :max_temperature, :max_wind_speed_m_s,
                    :max_application_count, :harvest_interval_days, :other_constraints

        def initialize(min_temperature:, max_temperature:, max_wind_speed_m_s:,
                      max_application_count:, harvest_interval_days:, other_constraints:)
          @min_temperature = min_temperature
          @max_temperature = max_temperature
          @max_wind_speed_m_s = max_wind_speed_m_s
          @max_application_count = max_application_count
          @harvest_interval_days = harvest_interval_days
          @other_constraints = other_constraints
        end
      end
    end
  end
end
