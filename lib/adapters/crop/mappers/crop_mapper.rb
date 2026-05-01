# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      class CropMapper
        def self.crop_entity_from_record(crop_model)
          crop_stages = crop_model.crop_stages.includes(
            :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement
          ).order(:order).map { |stage| crop_stage_entity_from_record(stage) }

          Domain::Crop::Entities::CropEntity.new(
            id: crop_model.id,
            user_id: crop_model.user_id,
            name: crop_model.name,
            variety: crop_model.variety,
            is_reference: crop_model.is_reference,
            area_per_unit: crop_model.area_per_unit,
            revenue_per_area: crop_model.revenue_per_area,
            region: crop_model.region,
            groups: crop_model.groups || [],
            crop_stages: crop_stages,
            created_at: crop_model.created_at,
            updated_at: crop_model.updated_at
          )
        end

        def self.crop_stage_entity_from_record(crop_stage_model)
          Domain::Crop::Entities::CropStageEntity.new(
            id: crop_stage_model.id,
            crop_id: crop_stage_model.crop_id,
            name: crop_stage_model.name,
            order: crop_stage_model.order,
            temperature_requirement: (crop_stage_model.temperature_requirement ? temperature_requirement_entity_from_record(crop_stage_model.temperature_requirement) : nil),
            thermal_requirement: (crop_stage_model.thermal_requirement ? thermal_requirement_entity_from_record(crop_stage_model.thermal_requirement) : nil),
            sunshine_requirement: (crop_stage_model.sunshine_requirement ? sunshine_requirement_entity_from_record(crop_stage_model.sunshine_requirement) : nil),
            nutrient_requirement: (crop_stage_model.nutrient_requirement ? nutrient_requirement_entity_from_record(crop_stage_model.nutrient_requirement) : nil),
            created_at: crop_stage_model.created_at,
            updated_at: crop_stage_model.updated_at
          )
        end

        def self.temperature_requirement_entity_from_record(model)
          Domain::Crop::Entities::TemperatureRequirementEntity.new(
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

        def self.thermal_requirement_entity_from_record(model)
          Domain::Crop::Entities::ThermalRequirementEntity.new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            required_gdd: model.required_gdd
          )
        end

        def self.sunshine_requirement_entity_from_record(model)
          Domain::Crop::Entities::SunshineRequirementEntity.new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            minimum_sunshine_hours: model.minimum_sunshine_hours,
            target_sunshine_hours: model.target_sunshine_hours
          )
        end

        def self.nutrient_requirement_entity_from_record(model)
          Domain::Crop::Entities::NutrientRequirementEntity.new(
            id: model.id,
            crop_stage_id: model.crop_stage_id,
            daily_uptake_n: model.daily_uptake_n,
            daily_uptake_p: model.daily_uptake_p,
            daily_uptake_k: model.daily_uptake_k,
            region: model.region
          )
        end

        def self.crop_task_schedule_blueprint_entity_from_record(record)
          at = record.agricultural_task
          at_entity = at ? Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(at) : nil
          Domain::Crop::Entities::CropTaskScheduleBlueprintEntity.new(
            id: record.id,
            crop_id: record.crop_id,
            gdd_trigger: record.gdd_trigger,
            priority: record.priority,
            task_type: record.task_type,
            description: record.description,
            stage_name: record.stage_name,
            agricultural_task: at_entity
          )
        end

      end
    end
  end
end
