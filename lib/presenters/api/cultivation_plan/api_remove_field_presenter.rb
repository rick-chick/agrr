# frozen_string_literal: true

module Presenters
  module Api
    module CultivationPlan
      class ApiRemoveFieldPresenter < Domain::CultivationPlan::Ports::ApiRemoveFieldOutputPort
        def initialize(view:, translation_scope:)
          @view = view
          @translation_scope = translation_scope
        end

        def on_success(field_id:, total_area:)
          @view.render json: {
            success: true,
            message: i18n_t("messages.field_removed"),
            field_id: field_id,
            total_area: total_area
          }
        end

        def on_not_found
          @view.render json: { success: false, message: i18n_t("errors.not_found") }, status: :not_found
        end

        def on_field_not_found
          @view.render json: { success: false, message: i18n_t("errors.field_not_found") }, status: :not_found
        end

        def on_cannot_remove_with_cultivations
          @view.render json: {
            success: false,
            message: i18n_t("errors.cannot_remove_field_with_cultivations")
          }, status: :unprocessable_entity
        end

        def on_cannot_remove_last_field
          @view.render json: {
            success: false,
            message: i18n_t("errors.cannot_remove_last_field")
          }, status: :unprocessable_entity
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
