# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      class PlanSaveUserAgriculturalTaskMappingAdapter <
          Domain::CultivationPlan::Ports::UserAgriculturalTaskMappingPort
        def initialize(
          reference_agricultural_task_id_to_user_task_id:,
          user_id:,
          plan_save_user_agricultural_task_gateway:
        )
          @reference_agricultural_task_id_to_user_task_id =
            reference_agricultural_task_id_to_user_task_id || {}
          @user_id = user_id.to_i
          @plan_save_user_agricultural_task_gateway = plan_save_user_agricultural_task_gateway
        end

        def user_task_id_for(reference_task_id:)
          return nil if reference_task_id.nil?

          PlanSaveAgriculturalTaskIdLookup.resolve(
            reference_task_id: reference_task_id,
            user_id: @user_id,
            map: @reference_agricultural_task_id_to_user_task_id,
            plan_save_user_agricultural_task_gateway: @plan_save_user_agricultural_task_gateway
          )
        end
      end
    end
  end
end
