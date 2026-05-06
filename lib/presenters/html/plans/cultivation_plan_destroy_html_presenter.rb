# frozen_string_literal: true

module Presenters
  module Html
    module Plans
      # HTML DELETE /plans/:id — CultivationPlanDestroyInteractor の出力（ApplicationController の削除 Undo 応答）
      class CultivationPlanDestroyHtmlPresenter < Domain::CultivationPlan::Ports::CultivationPlanDestroyOutputPort
        def initialize(view:)
          @view = view
          @dual = Presenters::DeletionUndo::DualFormatResponder.new(
            view: view,
            fallback_location: Rails.application.routes.url_helpers.plans_path,
            logger: view.logger
          )
        end

        def on_success(destroy_output_dto)
          @dual.render_scheduled_success(destroy_output_dto.undo)
        end

        def on_failure(error_dto)
          message = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          @dual.render_failure(message: message, status: failure_status_for(message))
        end

        private

        def failure_status_for(message)
          return :not_found if message == I18n.t("plans.errors.not_found")

          delete_failed_message = I18n.t("plans.errors.delete_failed")
          delete_error_prefix = I18n.t("plans.errors.delete_error", message: "")

          return :unprocessable_entity if message == delete_failed_message
          return :unprocessable_entity if message.start_with?(delete_error_prefix)

          :unprocessable_entity
        end
      end
    end
  end
end
