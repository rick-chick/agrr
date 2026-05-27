# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST add_crop: cultivation_plan_crops の永続化のみ。認可は Interactor + Policy。
      class CultivationPlanPlanCropGateway
        # @param user_id [Integer, nil] 指定時は private 計画を user スコープで narrow find してから create
        # @param crop_entity [Domain::Crop::Dtos::AddCropCropSnapshot, #id, #name, #variety, #area_per_unit, #revenue_per_area]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanCropSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(plan_id:, crop_entity:, user_id: nil)
          raise NotImplementedError
        end

        # プラン初期化用（REST 認可スコープ外）。永続化のみ。
        # @param attrs [Domain::CultivationPlan::Dtos::CultivationPlanPlanCropCreateAttrs]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanCropSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create_for_plan(attrs:)
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
