# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RemoveFieldInteractor
        def initialize(output:, plan_gateway:, field_mutation_gateway:, events_gateway:, logger:)
          @output = output
          @plan_gateway = plan_gateway
          @field_mutation_gateway = field_mutation_gateway
          @events_gateway = events_gateway
          @logger = logger
        end

        def call(auth:, plan_id:, field_id_param:)
          plan = @plan_gateway.find_by_id_for_rest(auth: auth, plan_id: plan_id)
          field_id = field_id_param.to_i
          field_row = @field_mutation_gateway.find_field(plan_id: plan.id, field_id: field_id)

          unless field_row
            return @output.on_field_not_found
          end

          if Policies::CultivationPlanFieldPolicy.cannot_remove_with_cultivations?(
            cultivation_count: field_row.cultivation_count
          )
            return @output.on_cannot_remove_with_cultivations
          end

          existing_count = @field_mutation_gateway.count_fields(plan_id: plan.id)
          if Policies::CultivationPlanFieldPolicy.cannot_remove_last_field?(existing_field_count: existing_count)
            return @output.on_cannot_remove_last_field
          end

          @field_mutation_gateway.delete_field(plan_id: plan.id, field_id: field_id)
          total_area = @field_mutation_gateway.refresh_total_area(plan_id: plan.id)

          @events_gateway.broadcast_field_removed(
            plan_id: plan.id,
            plan_type: plan.plan_type,
            field_id: field_id,
            total_area: total_area
          )

          @output.on_success(field_id: field_id, total_area: total_area)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output.on_not_found
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error "❌ [Remove Field] Record invalid: #{e.message}"
          @output.on_record_invalid(message: e.message)
        rescue StandardError => e
          @logger.error "❌ [Remove Field] Error: #{e.message}"
          @output.on_unexpected(message: e.message)
        end
      end
    end
  end
end
