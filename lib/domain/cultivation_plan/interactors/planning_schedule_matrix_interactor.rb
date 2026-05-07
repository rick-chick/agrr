# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PlanningScheduleMatrixInteractor
        def initialize(output_port:, user_id:, farm_gateway:, cultivation_plan_gateway:, user_lookup:, translator:, clock:, logger:)
          raise ArgumentError, "clock must respond to :today" unless clock.respond_to?(:today)

          @output_port = output_port
          @user_id = user_id
          @farm_gateway = farm_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @user_lookup = user_lookup
          @translator = translator
          @clock = clock
          @logger = logger
        end

        def call(
          farm_id_param:,
          field_ids_param:,
          session_farm_id:,
          session_field_ids:,
          year_param:,
          granularity_param:
        )
          user = @user_lookup.find(@user_id)

          farm_id = farm_id_param.to_i.nonzero? || session_farm_id.to_i
          field_ids = normalize_field_ids(field_ids_param).presence ||
            normalize_field_ids(session_field_ids).presence ||
            []

          if farm_id <= 0 || field_ids.blank?
            @output_port.on_redirect_fields_selection(alert_key: "planning_schedules.errors.select_fields")
            return
          end

          farm_row = @farm_gateway.planning_schedule_user_owned_farms(user: user).find { |f| f.id == farm_id }
          unless farm_row
            @output_port.on_redirect_fields_selection(alert_key: "planning_schedules.errors.farm_not_found")
            return
          end

          range_const = Domain::CultivationPlan::PlanningScheduleConstants::DEFAULT_YEARS_RANGE
          current_year = @clock.today.year
          next_year = current_year + 1

          all_fields = @cultivation_plan_gateway.aggregated_planning_schedule_fields(user: user, farm_id: farm_id)
          selected_fields = all_fields.select { |f| field_ids.include?(f[:id]) }

          start_year = year_param.to_i.nonzero? || (next_year - range_const + 1)
          granularity = granularity_param.presence || "quarter"

          year_range_allowed = ((next_year - range_const + 1)..next_year).to_a.reverse
          unless year_range_allowed.include?(start_year)
            start_year = next_year - range_const + 1
          end

          end_year = start_year + range_const - 1

          period_start = Date.new(start_year, 1, 1)
          period_end = Date.new(end_year, 12, 31)

          periods = Domain::CultivationPlan::Services::PlanningSchedulePeriodsBuilder.new(translator: @translator).call(
            start_date: period_start,
            end_date: period_end,
            granularity: granularity
          ).reverse

          cultivations_by_field = {}
          selected_fields.each do |field|
            cultivations_by_field[field[:id]] =
              @cultivation_plan_gateway.planning_schedule_cultivations_for_field(
                user: user,
                farm_id: farm_id,
                field_name: field[:name],
                period_start: period_start,
                period_end: period_end
              )
          end

          dto = Domain::CultivationPlan::Dtos::PlanningScheduleMatrixSuccessDto.new(
            farm: farm_row,
            selected_fields: selected_fields,
            periods: periods,
            cultivations_by_field: cultivations_by_field,
            start_year: start_year,
            end_year: end_year,
            year_range: year_range_allowed,
            years_range: range_const,
            granularity: granularity,
            session_farm_id: farm_id,
            session_field_ids: field_ids
          )

          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PlanningScheduleMatrixInteractor] user_not_found: #{e.message}")
          @output_port.on_redirect_fields_selection(alert_key: "planning_schedules.errors.select_fields")
        end

        private

        def normalize_field_ids(raw_ids)
          Array(raw_ids).filter_map do |field_id|
            value = field_id.to_s.strip
            next if value.blank?

            value.to_i
          end
        end
      end
    end
  end
end
