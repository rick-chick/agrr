# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # PlanSave 用 CropTaskScheduleBlueprintCopyInteractor 生成（proc 注入の代替）。
      class PlanSaveBlueprintCopyFactory
        def initialize(blueprint_gateway:, logger:)
          @blueprint_gateway = blueprint_gateway
          @logger = logger
        end

        # @param ctx [Adapters::CultivationPlan::Sessions::PlanSaveContext]
        def build_interactor(ctx)
          Domain::CultivationPlan::Interactors::CropTaskScheduleBlueprintCopyInteractor.new(
            blueprint_gateway: @blueprint_gateway,
            task_mapping_port: PlanSaveUserAgriculturalTaskMappingAdapter.new(ctx),
            logger: @logger
          )
        end
      end
    end
  end
end
