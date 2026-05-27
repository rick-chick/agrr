# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      # JSON 応答（Api::V1::CultivationPlanRestBaseController#add_crop）。scope 例: "plans", "public_plans"
      class AddCropApiPresenter < Domain::CultivationPlan::Ports::AddCropOutputPort
        def initialize(view:, translation_scope:)
          @view = view
          @translation_scope = translation_scope
        end

        def on_success(plan_crop_id:, plan_crop_display_name:)
          @view.render json: {
            success: true,
            message: i18n_t("messages.crop_added"),
            crop: {
              id: plan_crop_id,
              name: plan_crop_display_name
            }
          }
        end

        def on_not_found
          @view.render json: { success: false, message: i18n_t("errors.not_found") }, status: :not_found
        end

        def on_crop_not_found
          @view.render json: { success: false, message: i18n_t("errors.crop_not_found") }, status: :not_found
        end

        def on_prediction_incomplete(technical_details:)
          @view.render json: {
            success: false,
            message: i18n_t("errors.prediction_data_incomplete"),
            technical_details: technical_details
          }, status: :service_unavailable
        end

        def on_no_candidates
          @view.render json: {
            success: false,
            message: i18n_t("errors.no_candidates_found")
          }, status: :unprocessable_entity
        end

        def on_adjust_failed(adjust_result:)
          payload = {
            success: false,
            message: adjust_result.message
          }
          status = adjust_result.http_status || :internal_server_error
          @view.render json: payload, status: status
        end

        def on_record_invalid(message:)
          @view.render json: { success: false, message: message }, status: :unprocessable_entity
        end

        def on_unexpected(message:)
          @view.render json: { success: false, message: message }, status: :internal_server_error
        end

        private

        def i18n_t(key)
          I18n.t("#{@translation_scope}.#{key}")
        end
      end
    end
  end
end
