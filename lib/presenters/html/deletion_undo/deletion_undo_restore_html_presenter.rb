# frozen_string_literal: true

module Presenters
  module Html
    module DeletionUndo
      class DeletionUndoRestoreHtmlPresenter < Domain::DeletionUndo::Ports::DeletionUndoRestoreOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output_dto)
          @view.redirect_back fallback_location: @view.root_path,
                            notice: I18n.t('deletion_undo.restored')
        end

        def on_failure(error_dto)
          msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
          error_type = determine_error_type(msg)
          alert_message = error_message_for_display(error_type, msg)

          @view.redirect_back fallback_location: @view.root_path, alert: alert_message
        end

        private

        def determine_error_type(message)
          case message
          when /not found/i
            :not_found
          when /expired/i, /token/i
            :expired
          when /conflict/i
            :conflict
          else
            :general_error
          end
        end

        def error_message_for_display(error_type, original_message)
          case error_type
          when :not_found
            I18n.t('deletion_undo.not_found', default: 'Deletion undo not found')
          when :expired
            I18n.t('deletion_undo.expired', default: 'Undo token has expired')
          when :conflict
            I18n.t('deletion_undo.restore_failed', default: 'Restore failed due to conflict')
          else
            original_message
          end
        end
      end
    end
  end
end