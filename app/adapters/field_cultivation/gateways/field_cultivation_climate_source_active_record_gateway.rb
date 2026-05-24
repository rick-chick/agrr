# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateSourceActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateSourceGateway
        def find_plan_access_context(field_cultivation_id)
          fc = find_field_cultivation_model!(field_cultivation_id)
          plan = fc.cultivation_plan
          Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessContext.new(
            field_cultivation_id: fc.id,
            plan_type_public: plan.plan_type_public?,
            plan_type_private: plan.plan_type_private?,
            plan_user_id: plan.user_id
          )
        end

        def find_by_field_cultivation_id(field_cultivation_id)
          field_cultivation = find_field_cultivation_model!(field_cultivation_id)
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
            weather_location_present: !weather_location.nil?,
            weather_location_timezone: weather_location&.timezone,
            plan_id: plan.id,
            plan_type_public: plan.plan_type_public?,
            plan_predicted_weather_present: Domain::Shared::ValidationHelpers.present?(plan.predicted_weather_data),
            prediction_target_end_date: plan.prediction_target_end_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            plan_crop_crop_id: plan_crop&.crop_id
          )
        end

        def find_weather_prediction_targets_by_plan_id(plan_id)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          farm = plan.farm
          {
            weather_location: farm.weather_location,
            farm: farm
          }
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def find_api_summary(field_cultivation_id:)
          fc = find_field_cultivation_model!(field_cultivation_id)
          Domain::FieldCultivation::Dtos::FieldCultivationApiSummary.new(
            id: fc.id,
            field_name: fc.field_display_name,
            crop_name: fc.crop_display_name,
            area: fc.area,
            start_date: fc.start_date,
            completion_date: fc.completion_date,
            cultivation_days: fc.cultivation_days,
            estimated_cost: fc.estimated_cost,
            gdd: fc.optimization_result&.dig("raw", "total_gdd"),
            status: fc.status
          )
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil)
          fc = find_field_cultivation_model!(field_cultivation_id)
          attrs = { start_date: start_date, completion_date: completion_date }
          attrs[:cultivation_days] = cultivation_days unless cultivation_days.nil?
          unless fc.update(attrs)
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: fc.errors.full_messages)
          end

          Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput.new(
            field_cultivation_id: fc.id,
            start_date: fc.start_date,
            completion_date: fc.completion_date,
            cultivation_days: fc.cultivation_days
          )
        end

        private

        def find_field_cultivation_model!(field_cultivation_id)
          ::FieldCultivation.find(field_cultivation_id)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end
      end
    end
  end
end
