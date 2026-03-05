# frozen_string_literal: true

module Presenters
  module Api
    module DeletionUndo
      class DeletionUndoRestorePresenter < Domain::DeletionUndo::Ports::DeletionUndoRestoreOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output_dto)
          json = {
            status: output_dto.status,
            undo_token: output_dto.undo_token
          }
          @view.render_response(json: json, status: :ok)
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          error_type = determine_error_type(msg)
          status = http_status_for_error(error_type)
          display_msg = (error_type == :unprocessable_entity && msg.match?(/expired|token/i)) ? I18n.t('deletion_undo.expired', default: msg) : msg

          @view.render_response(json: { status: 'error', error: display_msg }, status: status)
        end

        private

        def determine_error_type(message)
          case message
          when /not found/i
            :not_found
          when /expired/i, /token/i
            :unprocessable_entity
          when /conflict/i
            :conflict
          else
            :internal_server_error
          end
        end

        def http_status_for_error(error_type)
          case error_type
          when :not_found then :not_found
          when :unprocessable_entity then :unprocessable_entity
          when :conflict then :conflict
          else :internal_server_error
          end
        end
      end
    end
  end
end