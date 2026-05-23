# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanWizardSelectCropOutputPort
        def on_missing_session
          raise NotImplementedError, "Subclasses must implement on_missing_session"
        end

        def on_missing_farm
          raise NotImplementedError, "Subclasses must implement on_missing_farm"
        end

        def on_invalid_farm_size(farm_id:)
          raise NotImplementedError, "Subclasses must implement on_invalid_farm_size"
        end

        def on_success(dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
