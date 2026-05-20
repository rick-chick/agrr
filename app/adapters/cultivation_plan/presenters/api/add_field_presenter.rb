# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class AddFieldPresenter < Domain::CultivationPlan::Ports::AddFieldOutputPort
          def initialize(view:, translation_scope:)
            @view = view
            @translation_scope = translation_scope
          end

          def on_success(field_id:, name:, area:, total_area:)
            @view.render json: {
              success: true,
              message: i18n_t("messages.field_added"),
              field: {
                id: field_id,
                field_id: field_id,
                name: name,
                area: area
              },
              total_area: total_area
            }
          end

          def on_not_found
            @view.render json: { success: false, message: i18n_t("errors.not_found") }, status: :not_found
          end

          def on_invalid_field_params
            @view.render json: { success: false, message: i18n_t("errors.invalid_field_params") }, status: :unprocessable_entity
          end

          def on_max_fields_limit
            @view.render json: { success: false, message: i18n_t("errors.max_fields_limit") }, status: :bad_request
          end

          def on_record_invalid(message:)
            @view.render json: {
              success: false,
              message: i18n_t("errors.field_add_failed", message: message)
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
end
