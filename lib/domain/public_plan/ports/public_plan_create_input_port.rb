# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanCreateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
