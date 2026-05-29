# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustReadActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanAllocationAdjustReadGateway
        Dtos = Domain::CultivationPlan::Dtos

        FIELD_CULTIVATION_INCLUDES = [
          :cultivation_plan_field,
          { cultivation_plan_crop: { crop: :crop_stages } }
        ].freeze

        def initialize(weather_data_gateway:)
          @weather_data_gateway = weather_data_gateway
        end

        def find_adjust_plan_header_snapshot_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          Dtos::PlanAllocationAdjustReadPlanHeaderSnapshot.new(
            id: plan.id,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            weather_prediction_targets:
              Adapters::WeatherData::Mappers::WeatherPredictionTargetsMapper.from_plan(plan)
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_adjust_plan_field_rows_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanField.where(cultivation_plan_id: plan_id).map do |field|
            Dtos::PlanAllocationAdjustReadPlanFieldRowSnapshot.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_adjust_field_cultivation_rows_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::FieldCultivation
            .includes(FIELD_CULTIVATION_INCLUDES)
            .where(cultivation_plan_id: plan_id)
            .map do |fc|
            crop = fc.cultivation_plan_crop.crop
            Dtos::PlanAllocationAdjustReadFieldCultivationRowSnapshot.new(
              id: fc.id,
              cultivation_plan_field_id: fc.cultivation_plan_field_id,
              crop_id: crop.id,
              crop_name: fc.crop_display_name,
              variety: fc.cultivation_plan_crop.variety,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              crop_stage_count: crop.crop_stages.size,
              estimated_cost: fc.estimated_cost,
              optimization_result: fc.optimization_result
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_adjust_plan_crop_rows_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanCrop.includes(crop: :crop_stages).where(cultivation_plan_id: plan_id).map do |plan_crop|
            crop = plan_crop.crop
            Dtos::PlanAllocationAdjustReadPlanCropRowSnapshot.new(
              crop_id: crop.id,
              crop_name: crop.name,
              groups: crop.groups,
              crop_stage_count: crop.crop_stages.size
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_historical_weather_rows(weather_location_id:, historical_start:, historical_end:)
          return [] if weather_location_id.blank?

          @weather_data_gateway.weather_data_for_period(
            weather_location_id: weather_location_id,
            start_date: historical_start,
            end_date: historical_end
          ).filter_map do |datum|
            next if datum.temperature_max.nil? || datum.temperature_min.nil?

            Domain::WeatherData::Dtos::HistoricalWeatherObservation.new(
              date: datum.date,
              temperature_max: datum.temperature_max,
              temperature_min: datum.temperature_min,
              temperature_mean: datum.temperature_mean,
              precipitation: datum.precipitation,
              sunshine_hours: datum.sunshine_hours,
              wind_speed: datum.wind_speed,
              weather_code: datum.weather_code
            )
          end
        end

        def plan_summary_for_adjust_response(plan_id:)
          plan = ::CultivationPlan.find(plan_id)
          { id: plan.id, field_cultivations_count: plan.field_cultivations.count }
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        private

        def ensure_plan_exists!(plan_id)
          ::CultivationPlan.find(plan_id)
        end
      end
    end
  end
end
