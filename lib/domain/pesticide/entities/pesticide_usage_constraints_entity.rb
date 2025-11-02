# frozen_string_literal: true

module Domain
  module Pesticide
    module Entities
      class PesticideUsageConstraintsEntity
        attr_reader :id, :pesticide_id, :min_temperature, :max_temperature,
                    :max_wind_speed_m_s, :max_application_count,
                    :harvest_interval_days, :other_constraints,
                    :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @pesticide_id = attributes[:pesticide_id]
          @min_temperature = attributes[:min_temperature]
          @max_temperature = attributes[:max_temperature]
          @max_wind_speed_m_s = attributes[:max_wind_speed_m_s]
          @max_application_count = attributes[:max_application_count]
          @harvest_interval_days = attributes[:harvest_interval_days]
          @other_constraints = attributes[:other_constraints]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def has_temperature_constraints?
          min_temperature.present? || max_temperature.present?
        end

        def has_wind_constraints?
          max_wind_speed_m_s.present?
        end

        private

        def validate!
          raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?

          if min_temperature && max_temperature
            raise ArgumentError, "Min temperature must be less than max temperature" if min_temperature > max_temperature
          end

          if max_wind_speed_m_s
            raise ArgumentError, "Max wind speed must be positive" if max_wind_speed_m_s < 0
          end

          if max_application_count
            raise ArgumentError, "Max application count must be positive" if max_application_count < 1
          end

          if harvest_interval_days
            raise ArgumentError, "Harvest interval must be non-negative" if harvest_interval_days < 0
          end
        end
      end
    end
  end
end

