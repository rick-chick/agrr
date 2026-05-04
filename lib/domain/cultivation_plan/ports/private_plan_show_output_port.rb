# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PrivatePlanShowOutputPort
        def on_success(dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
