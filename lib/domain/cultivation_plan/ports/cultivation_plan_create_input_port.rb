# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class CultivationPlanCreateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end