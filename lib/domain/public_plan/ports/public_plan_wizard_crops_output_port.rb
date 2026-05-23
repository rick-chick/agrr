# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanWizardCropsOutputPort
        def on_success(crops)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_farm_not_found
          raise NotImplementedError, "Subclasses must implement on_farm_not_found"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
