# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      # 参照作物の生育ステージ・要件をユーザー作物へ複製（旧 CopyReferenceCropStages）。
      class CropStageCopyActiveRecordGateway < Domain::Crop::Gateways::CropStageCopyGateway
        def copy_reference_stages(reference_crop_id:, new_crop_id:)
          reference_crop = ::Crop.find(reference_crop_id)
          new_crop = ::Crop.find(new_crop_id)
          reference_crop.crop_stages.each do |reference_stage|
            existing_stage = new_crop.crop_stages.find_by(name: reference_stage.name)
            stage = existing_stage || ::CropStage.create!(
              crop_id: new_crop.id,
              name: reference_stage.name,
              order: reference_stage.order
            )

            if reference_stage.temperature_requirement && !stage.temperature_requirement
              ::TemperatureRequirement.create!(
                crop_stage_id: stage.id,
                base_temperature: reference_stage.temperature_requirement.base_temperature,
                optimal_min: reference_stage.temperature_requirement.optimal_min,
                optimal_max: reference_stage.temperature_requirement.optimal_max,
                low_stress_threshold: reference_stage.temperature_requirement.low_stress_threshold,
                high_stress_threshold: reference_stage.temperature_requirement.high_stress_threshold,
                frost_threshold: reference_stage.temperature_requirement.frost_threshold,
                sterility_risk_threshold: reference_stage.temperature_requirement.sterility_risk_threshold,
                max_temperature: reference_stage.temperature_requirement.max_temperature
              )
            end

            if reference_stage.sunshine_requirement && !stage.sunshine_requirement
              ::SunshineRequirement.create!(
                crop_stage_id: stage.id,
                minimum_sunshine_hours: reference_stage.sunshine_requirement.minimum_sunshine_hours,
                target_sunshine_hours: reference_stage.sunshine_requirement.target_sunshine_hours
              )
            end

            if reference_stage.thermal_requirement && !stage.thermal_requirement
              ::ThermalRequirement.create!(
                crop_stage_id: stage.id,
                required_gdd: reference_stage.thermal_requirement.required_gdd
              )
            end

            next unless reference_stage.nutrient_requirement && !stage.nutrient_requirement

            ::NutrientRequirement.create!(
              crop_stage_id: stage.id,
              daily_uptake_n: reference_stage.nutrient_requirement.daily_uptake_n,
              daily_uptake_p: reference_stage.nutrient_requirement.daily_uptake_p,
              daily_uptake_k: reference_stage.nutrient_requirement.daily_uptake_k
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end
      end
    end
  end
end
