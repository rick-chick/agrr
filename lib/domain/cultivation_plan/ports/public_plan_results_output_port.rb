# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PublicPlanResultsOutputPort
        def on_not_found
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end

        def redirect_to_optimizing
          raise NotImplementedError, "Subclasses must implement redirect_to_optimizing"
        end

        # @param read_model [Domain::CultivationPlan::Dtos::PublicPlanResultsSnapshot]
        def on_success(read_model)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
