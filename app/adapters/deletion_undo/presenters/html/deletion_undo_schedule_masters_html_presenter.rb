# frozen_string_literal: true

module Adapters
  module DeletionUndo
    module Presenters
      module Html
        # HTML マスタ削除 — `Adapters::DeletionUndo::HtmlMasterScheduleInvoker` から起動（ApplicationController の削除 Undo 応答）
        class DeletionUndoScheduleMastersHtmlPresenter < Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort
          def initialize(view:, fallback_location:, delete_error_message_key:, in_use_message_key: nil)
            @view = view
            @fallback_location = fallback_location
            @delete_error_message_key = delete_error_message_key
            @in_use_message_key = in_use_message_key
            @dual = Adapters::DeletionUndo::Presenters::DualFormatResponder.new(
              view: view,
              fallback_location: fallback_location,
              logger: view.logger
            )
          end

          def on_success(entity)
            @dual.render_scheduled_success(entity)
          end

          def on_failure(dto)
            if dto.is_a?(Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure)
              message =
                case dto.reason
                when :association_in_use
                  if @in_use_message_key.present?
                    I18n.t(@in_use_message_key)
                  else
                    I18n.t(@delete_error_message_key, message: I18n.t("errors.messages.restrict_dependent_destroy"))
                  end
                when :forbidden
                  I18n.t("deletion_undo.schedule_forbidden")
                when :validation_error, :undo_system_error
                  I18n.t(@delete_error_message_key, message: dto.detail_message)
                else
                  I18n.t(@delete_error_message_key, message: dto.detail_message.presence || "")
                end

              @dual.render_failure(message: message)
            elsif dto.respond_to?(:message)
              @dual.render_failure(message: dto.message)
            else
              @dual.render_failure(message: dto.to_s)
            end
          end
        end
      end
    end
  end
end
