# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Html
        class PublicPlanWizardCropStepHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanWizardCropStepOutputPort
          def initialize(view:)
            @view = view
          end

          def on_missing_session
            @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
          end

          def on_missing_farm
            @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
          end

          def on_invalid_farm_size(farm_id:)
            @view.redirect_to @view.select_farm_size_public_plans_path(farm_id: farm_id),
                               alert: I18n.t("public_plans.errors.select_farm_size")
          end

          def on_success(farm:)
            @view.instance_variable_set(:@farm, farm)
          end
        end
      end
    end
  end
end
