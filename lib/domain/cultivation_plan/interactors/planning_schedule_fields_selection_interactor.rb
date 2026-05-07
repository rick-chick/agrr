# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PlanningScheduleFieldsSelectionInteractor
        def initialize(output_port:, user_id:, farm_gateway:, cultivation_plan_gateway:, user_lookup:, clock:)
          raise ArgumentError, "clock must respond to :today" unless clock.respond_to?(:today)

          @output_port = output_port
          @user_id = user_id
          @farm_gateway = farm_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @user_lookup = user_lookup
          @clock = clock
        end

        # @param farm_id_param [Object] params[:farm_id]
        # @param field_ids_param [Array] params[:field_ids]
        def call(farm_id_param:, field_ids_param:)
          user = @user_lookup.find(@user_id)

          farms = @farm_gateway.planning_schedule_user_owned_farms(user: user)

          selected_farm_id = farm_id_param&.to_i || farms.first&.id

          selected_farm = farms.find { |f| f.id == selected_farm_id }

          fields = []
          selected_field_ids = []

          if selected_farm_id && selected_farm
            fields = @cultivation_plan_gateway.aggregated_planning_schedule_fields(user: user, farm_id: selected_farm_id)

            requested_field_ids = normalize_field_ids(field_ids_param)
            allowed_ids = fields.map { |f| f[:id] }
            selected_field_ids = (requested_field_ids.presence || allowed_ids).map(&:to_i).uniq & allowed_ids
          elsif selected_farm_id && !selected_farm
            fields = []
            selected_field_ids = []
          end

          current_year = @clock.today.year
          next_year = current_year + 1
          range_const = Domain::CultivationPlan::PlanningScheduleConstants::DEFAULT_YEARS_RANGE
          year_range = ((next_year - range_const + 1)..next_year).to_a.reverse

          dto = Domain::CultivationPlan::Dtos::PlanningScheduleFieldsSelectionSuccessDto.new(
            farms: farms,
            selected_farm_id: selected_farm_id,
            selected_farm: selected_farm,
            fields: fields,
            selected_field_ids: selected_field_ids,
            year_range: year_range
          )

          @output_port.on_success(dto)
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
