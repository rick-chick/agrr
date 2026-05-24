# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST: 栽培計画圃場の永続化のみ。認可・ルールは Interactor + Policy。
      class CultivationPlanFieldMutationGateway
        # @return [Integer]
        def count_fields(plan_id:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot, nil]
        def find_field(plan_id:, field_id:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot]
        def create_field(plan_id:, field_name:, field_area:, daily_fixed_cost:)
          raise NotImplementedError
        end

        def delete_field(plan_id:, field_id:)
          raise NotImplementedError
        end

        # @return [Float] 更新後の total_area
        def refresh_total_area(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
