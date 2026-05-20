# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class ManualPlanAdjustPresenter < Domain::CultivationPlan::Ports::ManualPlanAdjustOutputPort
          def initialize(view:)
            @view = view
          end

          def on_crop_missing_growth_stages(crop_name:)
            @view.render json: {
              success: false,
              message: I18n.t("api.errors.cultivation_plan.crop_missing_growth_stages", crop_name: crop_name)
            }, status: :bad_request
          end

          def on_adjust(result:)
            @view.render json: result, status: result[:status] || :ok
          end

          def on_not_found
            @view.render json: {
              success: false,
              message: I18n.t("api.errors.common.not_found")
            }, status: :not_found
          end

          def on_unexpected(message:)
            @view.render json: { success: false, message: message }, status: :internal_server_error
          end
        end
      end
    end
  end
end
