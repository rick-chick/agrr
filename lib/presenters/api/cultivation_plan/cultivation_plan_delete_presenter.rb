# frozen_string_literal: true

module Presenters
  module Api
    module CultivationPlan
      class CultivationPlanDeletePresenter < Domain::CultivationPlan::Ports::CultivationPlanDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          @view.render_response(
            json: success_payload_for(event),
            status: :ok
          )
        end

        def on_failure(error_dto)
          message = failure_message(error_dto)
          @view.render_response(
            json: { error: message },
            status: failure_status_for(message)
          )
        end

        private

        def success_payload_for(event)
          {
            undo_token: event.undo_token,
            undo_deadline: event.metadata['undo_deadline'],
            toast_message: event.toast_message,
            undo_path: @view.undo_deletion_path(undo_token: event.undo_token),
            auto_hide_after: event.auto_hide_after,
            resource: resource_label_for(event),
            redirect_path: redirect_path,
            resource_dom_id: resource_dom_id_for(event)
          }
        end

        def resource_label_for(event)
          event.metadata['resource_label'] || event.metadata['resource']
        end

        def redirect_path
          '/plans'
        end

        def resource_dom_id_for(event)
          stored = event.metadata['resource_dom_id']
          return stored if stored.present?

          [event.resource_type.demodulize.underscore, event.resource_id].join('_')
        end

        def failure_message(error_dto)
          error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
        end

        def failure_status_for(message)
          return :not_found if message == I18n.t('plans.errors.not_found')

          delete_failed_message = I18n.t('plans.errors.delete_failed')
          delete_error_prefix = I18n.t('plans.errors.delete_error', message: '')

          return :unprocessable_entity if message == delete_failed_message
          return :unprocessable_entity if message.start_with?(delete_error_prefix)

          :unprocessable_entity
        end
      end
    end
  end
end
