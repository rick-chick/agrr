# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # PlanSave 用 CropTaskScheduleBlueprintCopyInteractor 生成（proc 注入の代替）。
      class PlanSaveBlueprintCopyFactory
        def initialize(blueprint_gateway:, logger:, plan_save_user_agricultural_task_gateway:)
          @blueprint_gateway = blueprint_gateway
          @logger = logger
          @plan_save_user_agricultural_task_gateway = plan_save_user_agricultural_task_gateway
        end

        # @param ctx [Adapters::CultivationPlan::Sessions::PlanSaveContext]
        def build_interactor(ctx)
          Domain::CultivationPlan::Interactors::CropTaskScheduleBlueprintCopyInteractor.new(
            blueprint_gateway: @blueprint_gateway,
            task_mapping_port: PlanSaveUserAgriculturalTaskMappingAdapter.new(
              reference_agricultural_task_id_to_user_task_id: ctx.reference_agricultural_task_id_to_user_task_id,
              user_id: ctx.user.id,
              plan_save_user_agricultural_task_gateway: @plan_save_user_agricultural_task_gateway
            ),
            logger: @logger
          )
        end
      end
    end
  end
end
