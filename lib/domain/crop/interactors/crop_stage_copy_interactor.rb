# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # 参照作物の生育ステージと各要件をユーザー作物へ複製する。
      class CropStageCopyInteractor
        def initialize(crop_gateway:)
          @crop_gateway = crop_gateway
        end

        # @param input [Domain::Crop::Dtos::CropStageCopyInput]
        def call(input)
          @crop_gateway.find_by_id(input.reference_crop_id)
          @crop_gateway.find_by_id(input.new_crop_id)

          reference_stages = @crop_gateway.list_by_crop_id(input.reference_crop_id)
          target_stages_by_name = @crop_gateway.list_by_crop_id(input.new_crop_id).each_with_object({}) do |stage, acc|
            acc[stage.name] = stage
          end

          reference_stages.each do |reference_stage|
            target_stage = target_stages_by_name[reference_stage.name] || create_stage(
              crop_id: input.new_crop_id,
              reference_stage: reference_stage
            )
            copy_requirements(reference_stage: reference_stage, target_stage: target_stage, new_crop_id: input.new_crop_id)
          end
        end

        private

        def create_stage(crop_id:, reference_stage:)
          @crop_gateway.create_crop_stage(
            Dtos::CropStageCreateInput.new(
              crop_id: crop_id,
              payload: { name: reference_stage.name, order: reference_stage.order }
            )
          )
        end

        def copy_requirements(reference_stage:, target_stage:, new_crop_id:)
          ref_temp = reference_stage.temperature_requirement
          if ref_temp && target_stage.temperature_requirement.nil?
            @crop_gateway.create_temperature_requirement(
              target_stage.id,
              Dtos::TemperatureRequirementUpdateInput.new(
                crop_id: new_crop_id,
                stage_id: target_stage.id,
                payload: temperature_payload(ref_temp)
              )
            )
          end

          ref_thermal = reference_stage.thermal_requirement
          if ref_thermal && target_stage.thermal_requirement.nil?
            @crop_gateway.create_thermal_requirement(
              target_stage.id,
              Dtos::ThermalRequirementUpdateInput.new(
                crop_id: new_crop_id,
                stage_id: target_stage.id,
                payload: { required_gdd: ref_thermal.required_gdd }
              )
            )
          end

          ref_sun = reference_stage.sunshine_requirement
          if ref_sun && target_stage.sunshine_requirement.nil?
            @crop_gateway.create_sunshine_requirement(
              target_stage.id,
              Dtos::SunshineRequirementUpdateInput.new(
                crop_id: new_crop_id,
                stage_id: target_stage.id,
                payload: {
                  minimum_sunshine_hours: ref_sun.minimum_sunshine_hours,
                  target_sunshine_hours: ref_sun.target_sunshine_hours
                }
              )
            )
          end

          ref_nutrient = reference_stage.nutrient_requirement
          return unless ref_nutrient && target_stage.nutrient_requirement.nil?

          @crop_gateway.create_nutrient_requirement(
            target_stage.id,
            Dtos::NutrientRequirementUpdateInput.new(
              crop_id: new_crop_id,
              stage_id: target_stage.id,
              payload: {
                daily_uptake_n: ref_nutrient.daily_uptake_n,
                daily_uptake_p: ref_nutrient.daily_uptake_p,
                daily_uptake_k: ref_nutrient.daily_uptake_k,
                region: ref_nutrient.region
              }
            )
          )
        end

        def temperature_payload(ref_temp)
          {
            base_temperature: ref_temp.base_temperature,
            optimal_min: ref_temp.optimal_min,
            optimal_max: ref_temp.optimal_max,
            low_stress_threshold: ref_temp.low_stress_threshold,
            high_stress_threshold: ref_temp.high_stress_threshold,
            frost_threshold: ref_temp.frost_threshold,
            sterility_risk_threshold: ref_temp.sterility_risk_threshold,
            max_temperature: ref_temp.max_temperature
          }
        end
      end
    end
  end
end
