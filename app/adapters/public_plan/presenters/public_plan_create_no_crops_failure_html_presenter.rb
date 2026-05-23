# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanCreateNoCropsFailureHtmlPresenter < Domain::PublicPlan::Ports::PublicPlanCreateNoCropsFailureOutputPort
        def initialize(view:)
          @view = view
        end

        def on_restart_required
          @view.redirect_to @view.public_plans_path, alert: I18n.t("public_plans.errors.restart")
        end

        def on_render_select_crop_no_crops_failure(farm:, farm_size:, crops:)
          @view.public_plan_render_select_crop_no_crops_failure!(
            farm: farm,
            farm_size: farm_size,
            crops: crops
          )
        end
      end
    end
  end
end
