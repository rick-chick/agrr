# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class AdjustWithDbWeatherPlanActiveRecordGateway < Domain::CultivationPlan::Gateways::AdjustWithDbWeatherPlanGateway
        ADJUST_INCLUDES = [
          :cultivation_plan_fields,
          { cultivation_plan_crops: :crop },
          { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: :crop } ] }
        ].freeze

        def initialize(logger:)
          @logger = logger
          @session_plan = nil
        end

        def begin_adjust_session!(plan_id)
          @session_plan = ::CultivationPlan.includes(*ADJUST_INCLUDES).find(plan_id)
        end

        def end_adjust_session!
          @session_plan = nil
        end

        def build_current_allocation(exclude_ids: [])
          payload_builder.build_current_allocation(exclude_ids: exclude_ids)
        end

        def build_fields_config
          payload_builder.build_fields_config
        end

        def build_crops_config
          payload_builder.build_crops_config
        end

        def build_interaction_rules
          payload_builder.build_interaction_rules
        end

        def farm_without_weather_location?
          @session_plan.farm.weather_location.blank?
        end

        def effective_planning_period(current_allocation:, moves:, as_of:)
          cultivation_periods = @session_plan.field_cultivations.map do |cultivation|
            {
              start_date: cultivation.start_date,
              completion_date: cultivation.completion_date
            }
          end

          Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
            current_allocation: current_allocation,
            moves: moves,
            cultivation_periods: cultivation_periods,
            planning_start_date: @session_plan.planning_start_date,
            planning_end_date: @session_plan.planning_end_date,
            as_of: as_of
          )
        end

        def reload_plan_record!
          @session_plan.reload
        end

        def cultivation_plan_weather_dto
          Domain::WeatherData::Dtos::CultivationPlanWeatherDto.new(
            id: @session_plan.id,
            prediction_target_end_date: @session_plan.prediction_target_end_date,
            calculated_planning_end_date: @session_plan.calculated_planning_end_date,
            predicted_weather_data: @session_plan.predicted_weather_data
          )
        end

        def weather_prediction_association_records
          wl = @session_plan.farm.weather_location
          { weather_location: wl, farm: @session_plan.farm }
        end

        def historical_weather_rows(historical_start:, historical_end:)
          wl = @session_plan.farm.weather_location
          return [] if wl.blank?

          wl.weather_data_for_period(historical_start, historical_end).filter_map do |datum|
            next if datum.temperature_max.nil? || datum.temperature_min.nil?

            {
              date: datum.date,
              temperature_max: datum.temperature_max,
              temperature_min: datum.temperature_min,
              temperature_mean: datum.temperature_mean,
              precipitation: datum.precipitation,
              sunshine_hours: datum.sunshine_hours,
              wind_speed: datum.wind_speed,
              weather_code: datum.weather_code
            }
          end
        end

        def weather_location_facts
          wl = @session_plan.farm.weather_location
          {
            latitude: wl.latitude.to_f,
            longitude: wl.longitude.to_f,
            elevation: (wl.elevation || 0.0).to_f,
            timezone: wl.timezone
          }
        end

        def broadcast_optimization_complete(plan_id:, events_gateway:, status:)
          plan = ::CultivationPlan.find(plan_id)
          events_gateway.broadcast_optimization_complete(plan: plan, status: status)
        end

        def plan_summary_for_adjust_response(plan_id:)
          plan = ::CultivationPlan.find(plan_id)
          { id: plan.id, field_cultivations_count: plan.field_cultivations.count }
        end

        private

        def payload_builder
          AgrrOptimizationPayloadBuilder.new(@session_plan, logger: @logger)
        end
      end
    end
  end
end
