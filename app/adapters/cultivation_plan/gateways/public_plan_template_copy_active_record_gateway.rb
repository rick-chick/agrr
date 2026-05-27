# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanTemplateCopyActiveRecordGateway < Domain::CultivationPlan::Gateways::PublicPlanTemplateCopyGateway
        def initialize(logger:, clock:, plan_save_user_agricultural_task_gateway:)
          @logger = logger
          @clock = clock
          @plan_save_user_agricultural_task_gateway = plan_save_user_agricultural_task_gateway
        end

        def copy_cultivation_plan(ctx:, farm:, crops:)
          plan_copy_gateway(ctx).copy_cultivation_plan(farm, crops)
        end

        def establish_master_data_relationships(ctx:, farm:, crops:, fields:, pests:, agricultural_tasks:, fertilizes:, pesticides:, interaction_rules:)
          plan_copy_gateway(ctx).establish_master_data_relationships(
            farm, crops, fields, pests, agricultural_tasks, fertilizes, pesticides, interaction_rules
          )
        end

        def copy_plan_relations(ctx:, new_plan:)
          plan_copy_gateway(ctx).copy_plan_relations(new_plan)
        end

        def copy_task_schedules(ctx:, new_plan:, field_cultivation_map:)
          plan_copy_gateway(ctx).copy_task_schedules(new_plan, field_cultivation_map)
        end

        private

        def plan_copy_gateway(ctx)
          PlanCopyActiveRecordGateway.new(
            ctx: ctx,
            logger: @logger,
            clock: @clock,
            plan_save_user_agricultural_task_gateway: @plan_save_user_agricultural_task_gateway
          )
        end
      end
    end
  end
end
