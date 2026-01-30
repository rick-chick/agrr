# frozen_string_literal: true

module Presenters
  module Api
    module Field
      class FieldDeletePresenter < Domain::Field::Ports::FieldDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          undo_path = @view.undo_deletion_path(undo_token: event.undo_token)
          json = {
            undo_token: event.undo_token,
            undo_deadline: event.metadata['undo_deadline'],
            toast_message: event.toast_message,
            undo_path: undo_path,
            auto_hide_after: event.auto_hide_after,
            resource: event.metadata['resource_label'],
            redirect_path: @view.farm_fields_path(event.metadata['farm_id']),
            resource_dom_id: resource_dom_id_for(event)
          }
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Field not found') ? :not_found : :unprocessable_entity
          @view.render_response(json: { error: msg }, status: status)
        end

        private

        def resource_dom_id_for(event)
          stored = event.metadata['resource_dom_id']
          return stored if stored.present?

          [event.resource_type.demodulize.underscore, event.resource_id].join('_')
        end
      end
    end
  end
end
