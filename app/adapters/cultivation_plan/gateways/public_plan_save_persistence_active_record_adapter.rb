# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSavePersistenceActiveRecordAdapter < Domain::CultivationPlan::Ports::PublicPlanSavePersistencePort
        def initialize(
          logger:,
          cultivation_plan_gateway:,
          crop_stage_copy_interactor:,
          blueprint_copy_factory:,
          template_copy_gateway:,
          plan_save_persist_orchestrator:,
          plan_save_farm_gateway:,
          plan_save_ensure_user_fields_interactor:,
          plan_save_ensure_user_crops_interactor:,
          plan_save_ensure_user_pests_interactor:,
          plan_save_field_gateway:,
          plan_save_user_crop_gateway:,
          plan_save_user_pest_gateway:
        )
          @logger = logger
          @cultivation_plan_gateway = cultivation_plan_gateway
          @crop_stage_copy_interactor = crop_stage_copy_interactor
          @blueprint_copy_factory = blueprint_copy_factory
          @template_copy_gateway = template_copy_gateway
          @plan_save_persist_orchestrator = plan_save_persist_orchestrator
          @plan_save_farm_gateway = plan_save_farm_gateway
          @plan_save_ensure_user_fields_interactor = plan_save_ensure_user_fields_interactor
          @plan_save_ensure_user_crops_interactor = plan_save_ensure_user_crops_interactor
          @plan_save_ensure_user_pests_interactor = plan_save_ensure_user_pests_interactor
          @plan_save_field_gateway = plan_save_field_gateway
          @plan_save_user_crop_gateway = plan_save_user_crop_gateway
          @plan_save_user_pest_gateway = plan_save_user_pest_gateway
        end

        def execute_save!(workspace:)
          user = ::User.find(workspace.user_id)
          session = Sessions::PlanSaveSession.new(
            user: user,
            session_data: workspace.session_hash,
            logger: @logger,
            cultivation_plan_gateway: @cultivation_plan_gateway,
            crop_stage_copy_interactor: @crop_stage_copy_interactor,
            blueprint_copy_factory: @blueprint_copy_factory,
            template_copy_gateway: @template_copy_gateway,
            plan_save_persist_orchestrator: @plan_save_persist_orchestrator,
            plan_save_farm_gateway: @plan_save_farm_gateway,
            plan_save_ensure_user_fields_interactor: @plan_save_ensure_user_fields_interactor,
            plan_save_ensure_user_crops_interactor: @plan_save_ensure_user_crops_interactor,
            plan_save_ensure_user_pests_interactor: @plan_save_ensure_user_pests_interactor,
            plan_save_field_gateway: @plan_save_field_gateway,
            plan_save_user_crop_gateway: @plan_save_user_crop_gateway,
            plan_save_user_pest_gateway: @plan_save_user_pest_gateway,
            own_transaction: false
          )
          result = session.call
          Domain::CultivationPlan::Dtos::PublicPlanSaveFromSessionOutput.new(
            success: result.success?,
            error_message: result.error_message,
            new_cultivation_plan_id: result.new_plan&.id,
            skipped_items: result.skipped_items
          )
        end
      end
    end
  end
end
