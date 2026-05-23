# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      class PlanAllocationAdjustApiPresenter < Domain::CultivationPlan::Ports::PlanAllocationAdjustOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output:)
          body = {
            success: true,
            message: output.message
          }
          body[:cultivation_plan] = output.cultivation_plan if output.cultivation_plan
          @view.render json: body, status: :ok
        end

        def on_failure(failure:)
          @view.render json: {
            success: false,
            message: failure.message
          }, status: Mappers::PlanAllocationAdjustFailureHttpMapper.http_status_for(failure.kind)
        end
      end
    end
  end
end
