# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestFieldMutationActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanRestFieldMutationGateway
        def initialize(events_gateway:, logger:)
          super(events_gateway: events_gateway, logger: logger)
        end

        def add_field(auth:, plan_id:, field_name:, field_area:, daily_fixed_cost:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          field_area_f = field_area&.to_f
          return { kind: :invalid_field_params } if field_area_f <= 0
          return { kind: :max_fields_limit } if cultivation_plan.cultivation_plan_fields.count >= 5

          plan_field = cultivation_plan.cultivation_plan_fields.create!(
            name: field_name,
            area: field_area_f,
            daily_fixed_cost: daily_fixed_cost&.to_f
          )

          cultivation_plan.update!(total_area: cultivation_plan.cultivation_plan_fields.sum(:area))

          events_gateway.broadcast_field_added(
            plan: cultivation_plan,
            field_payload: {
              id: plan_field.id,
              field_id: plan_field.id,
              name: plan_field.name,
              area: plan_field.area
            },
            total_area: cultivation_plan.total_area
          )

          { kind: :success, plan_field: plan_field, total_area: cultivation_plan.total_area }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Add Field] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue StandardError => e
          logger.error "❌ [Add Field] Error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end

        def remove_field(auth:, plan_id:, field_id_param:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)

          field_id = field_id_param.to_i
          plan_field = cultivation_plan.cultivation_plan_fields.find_by(id: field_id)

          unless plan_field
            return { kind: :field_not_found }
          end

          return { kind: :cannot_remove_with_cultivations } if plan_field.field_cultivations.any?

          return { kind: :cannot_remove_last_field } if cultivation_plan.cultivation_plan_fields.count <= 1

          plan_field.destroy!

          cultivation_plan.update!(total_area: cultivation_plan.cultivation_plan_fields.sum(:area))

          events_gateway.broadcast_field_removed(
            plan: cultivation_plan,
            field_id: field_id,
            total_area: cultivation_plan.total_area
          )

          { kind: :success, field_id: field_id, total_area: cultivation_plan.total_area }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Remove Field] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue StandardError => e
          logger.error "❌ [Remove Field] Error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
