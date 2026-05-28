# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustReadActiveRecordGateway < Domain::CultivationPlan::Gateways::PlanAllocationAdjustReadGateway
        ADJUST_INCLUDES = [
          :cultivation_plan_fields,
          { cultivation_plan_crops: :crop },
          { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: :crop } ] },
          { farm: :weather_location }
        ].freeze

        def initialize(weather_data_gateway:, crop_agrr_requirement_builder:)
          @weather_data_gateway = weather_data_gateway
          @crop_agrr_requirement_builder = crop_agrr_requirement_builder
        end

        def find_adjust_read_snapshot_by_plan_id(plan_id:)
          snapshot_from_plan(load_plan_unscoped(plan_id))
        end

        def find_adjust_read_snapshot_by_plan_id_and_user_id(plan_id:, user_id:)
          snapshot_from_plan(load_plan_for_rest_private(plan_id: plan_id, user_id: user_id))
        end

        def find_adjust_read_snapshot_by_plan_id_public(plan_id:)
          snapshot_from_plan(load_plan_for_rest_public(plan_id: plan_id))
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

        def snapshot_from_plan(plan)
          Mappers::PlanAllocationAdjustReadSnapshotMapper.from_cultivation_plan(
            plan,
            crop_agrr_requirement_builder: @crop_agrr_requirement_builder
          )
        end

        def load_plan_unscoped(plan_id)
          ::CultivationPlan.includes(*ADJUST_INCLUDES).find(plan_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def load_plan_for_rest_private(plan_id:, user_id:)
          user = ::User.find(user_id)
          ::CultivationPlan.plan_type_private.by_user(user).includes(*ADJUST_INCLUDES).find(plan_id.to_i)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def load_plan_for_rest_public(plan_id:)
          ::CultivationPlan.plan_type_public.includes(*ADJUST_INCLUDES).find(plan_id.to_i)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
