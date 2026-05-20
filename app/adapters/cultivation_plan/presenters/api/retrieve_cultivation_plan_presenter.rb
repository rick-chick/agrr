# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class RetrieveCultivationPlanPresenter < Domain::CultivationPlan::Ports::RetrieveCultivationPlanOutputPort
          def initialize(view:, translation_scope:)
            @view = view
            @translation_scope = translation_scope
          end

          def on_success(body:)
            @view.render json: body
          end

          def on_not_found
            @view.render json: { success: false, message: i18n_t("errors.not_found") }, status: :not_found
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
