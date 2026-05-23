# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class RetrieveCultivationPlanOutputPort
        # @param snapshot [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        def on_success(snapshot:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
