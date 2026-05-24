# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationClimateContextSnapshotMapper
        module_function

        # @param source [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        # @param crop [Domain::Crop::Entities::CropEntity]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        def to_context_snapshot(source:, crop:)
          stages = build_stage_requirements(crop)
          first_stage = crop.crop_stages.min_by { |st| st.order.to_i }
          temp_req = first_stage&.temperature_requirement

          Dtos::FieldCultivationClimateContextSnapshot.new(
            field_cultivation_id: source.field_cultivation_id,
            field_name: source.field_name,
            crop_name: source.crop_name,
            start_date: source.start_date,
            completion_date: source.completion_date,
            farm_id: source.farm_id,
            farm_name: source.farm_name,
            farm_latitude: source.farm_latitude,
            farm_longitude: source.farm_longitude,
            plan_id: source.plan_id,
            plan_type_public: source.plan_type_public,
            plan_predicted_weather_present: source.plan_predicted_weather_present,
            prediction_target_end_date: source.prediction_target_end_date,
            calculated_planning_end_date: source.calculated_planning_end_date,
            predicted_weather_data: source.predicted_weather_data,
            crop_id: crop.id,
            base_temperature: temp_req&.base_temperature || 10.0,
            optimal_temperature_range: build_optimal_temperature_range(temp_req),
            stages: stages
          )
        end

        def build_optimal_temperature_range(temp_req)
          return nil unless temp_req

          {
            min: temp_req.optimal_min,
            max: temp_req.optimal_max,
            low_stress: temp_req.low_stress_threshold,
            high_stress: temp_req.high_stress_threshold
          }
        end

        def build_stage_requirements(crop)
          return [] if crop.crop_stages.empty?

          cumulative_gdd = 0.0

          crop.crop_stages.sort_by { |st| st.order.to_i }.filter_map do |crop_stage|
            temp_req = crop_stage.temperature_requirement
            thermal_req = crop_stage.thermal_requirement
            next unless temp_req && thermal_req

            cumulative_gdd += thermal_req.required_gdd

            {
              name: crop_stage.name,
              order: crop_stage.order,
              gdd_required: thermal_req.required_gdd,
              cumulative_gdd_required: cumulative_gdd.round(2),
              optimal_temperature_min: temp_req.optimal_min,
              optimal_temperature_max: temp_req.optimal_max,
              low_stress_threshold: temp_req.low_stress_threshold,
              high_stress_threshold: temp_req.high_stress_threshold
            }
          end
        end
      end
    end
  end
end
