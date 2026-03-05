# frozen_string_literal: true

module Presenters
  module Api
    module Crop
      class CropDeletePresenter < Domain::Crop::Ports::CropDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          event = destroy_output_dto.undo
          undo_path = @view.undo_deletion_path(undo_token: event.undo_token)
          undo_json = {
            undo_token: event.undo_token,
            undo_path: undo_path,
            toast_message: event.toast_message,
            undo_deadline: event.expires_at.iso8601,
            auto_hide_after: event.auto_hide_after
          }
          @view.render_response(json: { undo: undo_json }, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          status = (msg == 'Crop not found') ? :not_found : :unprocessable_entity
          @view.render_response(json: { error: msg }, status: status)
        end

        private
      end
    end
  end
end
