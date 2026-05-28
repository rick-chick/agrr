# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      # ActiveRecord → domain Snapshot（wire のみ。業務判断なし）。
      module FieldCultivationClimateSourceSnapshotMapper
        module_function

        # @param field_cultivation [FieldCultivation]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot]
        def plan_access_snapshot_from_model(field_cultivation)
          plan = field_cultivation.cultivation_plan
          Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot.new(
            field_cultivation_id: field_cultivation.id,
            plan_type_public: plan.plan_type_public?,
            plan_type_private: plan.plan_type_private?,
            plan_user_id: plan.user_id
          )
        end

        # @param field_cultivation [FieldCultivation]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        def climate_source_snapshot_from_model(field_cultivation)
          plan = field_cultivation.cultivation_plan
          farm = plan.farm
          weather_location = farm&.weather_location
          plan_crop = field_cultivation.cultivation_plan_crop

          Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot.new(
            field_cultivation_id: field_cultivation.id,
            field_name: field_cultivation.field_display_name,
            crop_name: field_cultivation.crop_display_name,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            farm_id: farm.id,
            farm_name: farm.display_name,
            farm_latitude: farm.latitude,
            farm_longitude: farm.longitude,
            weather_location_id: weather_location&.id,
            weather_location_timezone: weather_location&.timezone,
            plan_id: plan.id,
            plan_type_public: plan.plan_type_public?,
            prediction_target_end_date: plan.prediction_target_end_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            plan_crop_crop_id: plan_crop&.crop_id
          )
        end
      end
    end
  end
end
