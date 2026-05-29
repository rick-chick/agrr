# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 年度私有コピー用の狭い永続化ポート（CRUD のみ）。
      class PlanCopyGateway
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_plan(source_plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Domain::CultivationPlan::Dtos::PlanCopyFieldRow>]
        def list_fields(source_plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Domain::CultivationPlan::Dtos::PlanCopyCropRow>]
        def list_crops(source_plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Domain::CultivationPlan::Dtos::PlanCopyFieldCultivationRow>]
        def list_field_cultivations(source_plan_id:)
          raise NotImplementedError
        end

        # @param attrs [Domain::CultivationPlan::Dtos::PlanCopyCreateAttrs]
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def create_plan(attrs:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::PlanCopyFieldRow]
        def create_field(plan_id:, name:, area:, daily_fixed_cost:, description: nil)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::PlanCopyCropRow]
        def create_crop(plan_id:, crop_id:, name:, variety:, area_per_unit:, revenue_per_area:)
          raise NotImplementedError
        end

        def create_field_cultivation(plan_id:, cultivation_plan_field_id:, cultivation_plan_crop_id:, area:, status:)
          raise NotImplementedError
        end
      end
    end
  end
end
