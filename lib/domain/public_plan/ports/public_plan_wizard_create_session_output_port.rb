# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanWizardCreateSessionOutputPort
        def on_invalid_session
          raise NotImplementedError, "Subclasses must implement on_invalid_session"
        end

        def on_valid
          raise NotImplementedError, "Subclasses must implement on_valid"
        end
      end
    end
  end
end
