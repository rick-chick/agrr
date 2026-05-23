# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanWizardValidateCreateSessionInteractor
        def initialize(output_port:)
          @output_port = output_port
        end

        def call(session_data:)
          if session_data[:farm_id].blank? || session_data[:total_area].blank?
            @output_port.on_invalid_session
            return false
          end

          @output_port.on_valid
          true
        end
      end
    end
  end
end
