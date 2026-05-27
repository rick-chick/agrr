# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSavePesticideUsageConstraintRow
        attr_reader :min_temperature, :max_temperature, :max_wind_speed_m_s,
                    :max_application_count, :harvest_interval_days, :other_constraints

        def initialize(
          min_temperature: nil,
          max_temperature: nil,
          max_wind_speed_m_s: nil,
          max_application_count: nil,
          harvest_interval_days: nil,
          other_constraints: nil
        )
          @min_temperature = min_temperature
          @max_temperature = max_temperature
          @max_wind_speed_m_s = max_wind_speed_m_s
          @max_application_count = max_application_count
          @harvest_interval_days = harvest_interval_days
          @other_constraints = other_constraints
          freeze
        end
      end
    end
  end
end
