# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractor
        def initialize(output:, plan_gateway:, field_mutation_gateway:, events_gateway:, logger:)
          @output = output
          @plan_gateway = plan_gateway
          @field_mutation_gateway = field_mutation_gateway
          @events_gateway = events_gateway
          @logger = logger
        end

        def call(auth:, plan_id:, field_name:, field_area:, daily_fixed_cost:)
          plan = @plan_gateway.find_by_id_for_rest(auth: auth, plan_id: plan_id)
          field_area_f = field_area&.to_f

          if Policies::CultivationPlanFieldPolicy.invalid_field_area?(field_area: field_area_f)
            return @output.on_invalid_field_params
          end

          existing_count = @field_mutation_gateway.count_fields(plan_id: plan.id)
          if Policies::CultivationPlanFieldPolicy.max_fields_reached?(existing_field_count: existing_count)
            return @output.on_max_fields_limit
          end

          field_snapshot = @field_mutation_gateway.create_field(
            plan_id: plan.id,
            field_name: field_name,
            field_area: field_area_f,
            daily_fixed_cost: daily_fixed_cost
          )
          total_area = @field_mutation_gateway.refresh_total_area(plan_id: plan.id)

          event_field = Dtos::FieldOptimizationEventSnapshot.new(
            id: field_snapshot.id,
            field_id: field_snapshot.id,
            name: field_snapshot.name,
            area: field_snapshot.area
          )
          @events_gateway.broadcast_field_added(
            plan_id: plan.id,
            plan_type: plan.plan_type,
            field_snapshot: event_field,
            total_area: total_area
          )

          @output.on_success(
            field_id: field_snapshot.id,
            name: field_snapshot.name,
            area: field_snapshot.area,
            total_area: total_area
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output.on_not_found
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error "❌ [Add Field] Record invalid: #{e.message}"
          @output.on_record_invalid(message: e.message)
        rescue StandardError => e
          @logger.error "❌ [Add Field] Error: #{e.message}"
          @output.on_unexpected(message: e.message)
        end
      end
    end
  end
end
