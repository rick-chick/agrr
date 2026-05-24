# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanFieldMutationActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanFieldMutationGateway
        def count_fields(plan_id:)
          ::CultivationPlanField.where(cultivation_plan_id: plan_id).count
        end

        def find_field(plan_id:, field_id:)
          plan_field = ::CultivationPlanField.find_by(cultivation_plan_id: plan_id, id: field_id)
          return nil unless plan_field

          snapshot_from_model(plan_field)
        end

        def create_field(plan_id:, field_name:, field_area:, daily_fixed_cost:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          plan_field = cultivation_plan.cultivation_plan_fields.create!(
            name: field_name,
            area: field_area.to_f,
            daily_fixed_cost: daily_fixed_cost&.to_f
          )
          snapshot_from_model(plan_field)
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def delete_field(plan_id:, field_id:)
          plan_field = ::CultivationPlanField.find_by!(cultivation_plan_id: plan_id, id: field_id)
          plan_field.destroy!
        end

        def refresh_total_area(plan_id:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          total = cultivation_plan.cultivation_plan_fields.sum(:area)
          cultivation_plan.update!(total_area: total)
          total
        end

        private

        def snapshot_from_model(plan_field)
          Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot.new(
            id: plan_field.id,
            name: plan_field.name,
            area: plan_field.area,
            cultivation_count: plan_field.field_cultivations.count
          )
        end
      end
    end
  end
end
