# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      # ActiveRecord をドメイン境界越しに出さず、作物マスタ HTML 用 {Domain::Crop::Dtos::CropMasterFormSnapshot} を組み立てる。
      class CropMasterFormSnapshotMapper
        class << self
          # @param crop [Crop]
          # @param error_messages [Array<String>]
          # @return [Domain::Crop::Dtos::CropMasterFormSnapshot]
          def from_record(crop, error_messages: [])
            stages = crop.crop_stages.sort_by(&:order).map { |st| stage_snapshot_from_record(st) }

            Domain::Crop::Dtos::CropMasterFormSnapshot.new(
              id: crop.id,
              user_id: crop.user_id,
              name: crop.name,
              variety: crop.variety,
              region: crop.region,
              groups: crop.groups || [],
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area,
              is_reference: crop.is_reference,
              crop_stages: stages,
              new_record: crop.new_record?,
              error_messages: Array(error_messages)
            )
          end

          private

          def stage_snapshot_from_record(stage)
            Domain::Crop::Dtos::CropMasterFormSnapshot::StageSnapshot.new(
              id: stage.id,
              crop_id: stage.crop_id,
              name: stage.name,
              order: stage.order,
              _destroy: false,
              temperature_requirement: temperature_snapshot_from(stage.temperature_requirement),
              thermal_requirement: thermal_snapshot_from(stage.thermal_requirement),
              sunshine_requirement: sunshine_snapshot_from(stage.sunshine_requirement),
              nutrient_requirement: nutrient_snapshot_from(stage.nutrient_requirement)
            )
          end

          def temperature_snapshot_from(model)
            if model
              Domain::Crop::Dtos::CropMasterFormSnapshot::TemperatureSnapshot.new(
                id: model.id,
                base_temperature: model.base_temperature,
                optimal_min: model.optimal_min,
                optimal_max: model.optimal_max,
                low_stress_threshold: model.low_stress_threshold,
                high_stress_threshold: model.high_stress_threshold,
                frost_threshold: model.frost_threshold,
                sterility_risk_threshold: model.sterility_risk_threshold,
                max_temperature: model.max_temperature,
                _destroy: false
              )
            else
              Domain::Crop::Dtos::CropMasterFormSnapshot::TemperatureSnapshot.new
            end
          end

          def thermal_snapshot_from(model)
            if model
              Domain::Crop::Dtos::CropMasterFormSnapshot::ThermalSnapshot.new(
                id: model.id,
                required_gdd: model.required_gdd,
                _destroy: false
              )
            else
              Domain::Crop::Dtos::CropMasterFormSnapshot::ThermalSnapshot.new
            end
          end

          def sunshine_snapshot_from(model)
            if model
              Domain::Crop::Dtos::CropMasterFormSnapshot::SunshineSnapshot.new(
                id: model.id,
                minimum_sunshine_hours: model.minimum_sunshine_hours,
                target_sunshine_hours: model.target_sunshine_hours,
                _destroy: false
              )
            else
              Domain::Crop::Dtos::CropMasterFormSnapshot::SunshineSnapshot.new
            end
          end

          def nutrient_snapshot_from(model)
            if model
              Domain::Crop::Dtos::CropMasterFormSnapshot::NutrientSnapshot.new(
                id: model.id,
                daily_uptake_n: model.daily_uptake_n,
                daily_uptake_p: model.daily_uptake_p,
                daily_uptake_k: model.daily_uptake_k,
                region: model.region,
                _destroy: false
              )
            else
              Domain::Crop::Dtos::CropMasterFormSnapshot::NutrientSnapshot.new
            end
          end
        end
      end
    end
  end
end
