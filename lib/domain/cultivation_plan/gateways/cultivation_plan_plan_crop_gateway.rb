# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST add_crop: cultivation_plan_crops の永続化のみ。認可は PlanScopes（adapter）。
      class CultivationPlanPlanCropGateway
        # @param auth [Domain::CultivationPlan::Dtos::CultivationPlanRestAuth]
        # @param crop_entity [#id, #name, #variety, #area_per_unit, #revenue_per_area]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanCropSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(auth:, plan_id:, crop_entity:)
          raise NotImplementedError
        end

        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def delete(id:)
          raise NotImplementedError
        end
      end
    end
  end
end
