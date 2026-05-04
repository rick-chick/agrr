# frozen_string_literal: true

module Presenters
  module Api
    module CultivationPlan
      # JSON 応答（CultivationPlanApi#add_crop）。scope 例: "plans", "public_plans"
      class ApiAddCropPresenter < Domain::CultivationPlan::Ports::ApiAddCropOutputPort
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

        def on_adjust_failed(adjust_payload:)
          @view.render json: adjust_payload, status: adjust_payload[:status] || :internal_server_error
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
