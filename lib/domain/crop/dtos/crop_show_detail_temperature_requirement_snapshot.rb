# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailTemperatureRequirementSnapshot
        attr_reader :id, :crop_stage_id, :base_temperature, :optimal_min, :optimal_max,
                    :low_stress_threshold, :high_stress_threshold, :frost_threshold,
                    :sterility_risk_threshold, :max_temperature

        def initialize(id:, crop_stage_id:, base_temperature:, optimal_min:, optimal_max:,
                       low_stress_threshold:, high_stress_threshold:, frost_threshold:,
                       sterility_risk_threshold:, max_temperature:)
          @id = id
          @crop_stage_id = crop_stage_id
          @base_temperature = base_temperature
          @optimal_min = optimal_min
          @optimal_max = optimal_max
          @low_stress_threshold = low_stress_threshold
          @high_stress_threshold = high_stress_threshold
          @frost_threshold = frost_threshold
          @sterility_risk_threshold = sterility_risk_threshold
          @max_temperature = max_temperature
          freeze
        end
      end
    end
  end
end
