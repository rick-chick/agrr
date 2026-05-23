# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanWizardSelectFarmSizeOutputPort
        def on_missing_farm(alert_i18n_key:)
          raise NotImplementedError, "Subclasses must implement on_missing_farm"
        end

        def on_success(dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
