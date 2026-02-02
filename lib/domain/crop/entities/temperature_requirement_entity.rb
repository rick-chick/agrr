# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class TemperatureRequirementEntity
        attr_reader :id, :crop_stage_id, :base_temperature, :optimal_min, :optimal_max,
                    :low_stress_threshold, :high_stress_threshold, :frost_threshold,
                    :sterility_risk_threshold, :max_temperature

        def initialize(attributes)
          @id = attributes[:id]
          @crop_stage_id = attributes[:crop_stage_id]
          @base_temperature = attributes[:base_temperature]
          @optimal_min = attributes[:optimal_min]
          @optimal_max = attributes[:optimal_max]
          @low_stress_threshold = attributes[:low_stress_threshold]
          @high_stress_threshold = attributes[:high_stress_threshold]
          @frost_threshold = attributes[:frost_threshold]
          @sterility_risk_threshold = attributes[:sterility_risk_threshold]
          @max_temperature = attributes[:max_temperature]

          validate!
        end

        # ActiveRecordモデルからの変換
        def self.from_model(model)
          new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            base_temperature: model.base_temperature,
            optimal_min: model.optimal_min,
            optimal_max: model.optimal_max,
            low_stress_threshold: model.low_stress_threshold,
            high_stress_threshold: model.high_stress_threshold,
            frost_threshold: model.frost_threshold,
            sterility_risk_threshold: model.sterility_risk_threshold,
            max_temperature: model.max_temperature
          )
        end

        private

        def validate!
          raise ArgumentError, "Crop stage ID is required" if crop_stage_id.blank?
        end
      end
    end
  end
end