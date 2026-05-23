# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PlanAllocationAdjustOutputPort
        # @param output [Domain::CultivationPlan::Dtos::PlanAllocationAdjustOutput]
        def on_success(output:)
          raise NotImplementedError
        end

        # @param failure [Domain::CultivationPlan::Dtos::PlanAllocationAdjustFailure]
        def on_failure(failure:)
          raise NotImplementedError
        end
      end
    end
  end
end
