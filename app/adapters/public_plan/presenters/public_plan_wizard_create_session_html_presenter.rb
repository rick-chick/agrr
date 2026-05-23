# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanWizardCreateSessionHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanWizardCreateSessionOutputPort
        def initialize(view:)
          @view = view
        end

        def on_invalid_session
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
        end

        def on_valid
          nil
        end
      end
    end
  end
end
