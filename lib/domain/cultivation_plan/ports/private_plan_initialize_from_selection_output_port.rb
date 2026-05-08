# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      module PrivatePlanInitializeFromSelectionOutputPort
        def on_success(dto)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
