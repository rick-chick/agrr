# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      class PublicPlanWizardCropsApiPresenter < Domain::PublicPlan::Ports::PublicPlanWizardCropsOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(crops)
          @view.render json: crops
        end

        def on_farm_not_found
          @view.render json: {
            error: I18n.t("api.errors.common.farm_not_found"),
            error_key: "api.errors.common.farm_not_found"
          }, status: :not_found
        end

        def on_failure(error_dto)
          @view.render json: { error: error_dto.message }, status: :internal_server_error
        end
      end
    end
  end
end
