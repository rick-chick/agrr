# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PlanAllocationAdjustInputPort
        # @param input [Domain::CultivationPlan::Dtos::PlanAllocationAdjustInput]
        def call(input)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
