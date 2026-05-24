# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanCheckOptimizationCompletionInteractor
        def initialize(cultivation_plan_gateway:)
          @cultivation_plan_gateway = cultivation_plan_gateway
        end

        def call(input_dto)
          plan = @cultivation_plan_gateway.find_by_id(input_dto.plan_id)
          field_cultivations = @cultivation_plan_gateway.list_by_plan_id(input_dto.plan_id)
          statuses = field_cultivations.map(&:status)

          return plan unless Policies::CultivationPlanOptimizationCompletePolicy.should_mark_plan_completed?(
            plan_status: plan.status,
            field_cultivation_statuses: statuses
          )

          @cultivation_plan_gateway.update(input_dto.plan_id, { status: "completed" })
        end
      end
    end
  end
end
