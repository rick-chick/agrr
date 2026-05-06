# frozen_string_literal: true

module Presenters
  module Html
    module DeletionUndo
      # HTML マスタ削除 — `DeletionUndo::HtmlMasterScheduleInvoker` から起動（ApplicationController の削除 Undo 応答）
      class DeletionUndoScheduleMastersHtmlPresenter < Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort
        def initialize(view:, fallback_location:, delete_error_message_key:, in_use_message_key: nil)
          @view = view
          @fallback_location = fallback_location
          @delete_error_message_key = delete_error_message_key
          @in_use_message_key = in_use_message_key
        end

        def on_success(entity)
          @view.send(
            :render_deletion_undo_response,
            entity,
            fallback_location: @fallback_location
          )
        end

        def on_failure(dto)
          if dto.is_a?(Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto)
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

            @view.send(
              :render_deletion_failure,
              message: message,
              fallback_location: @fallback_location
            )
          elsif dto.respond_to?(:message)
            @view.send(
              :render_deletion_failure,
              message: dto.message,
              fallback_location: @fallback_location
            )
          else
            @view.send(
              :render_deletion_failure,
              message: dto.to_s,
              fallback_location: @fallback_location
            )
          end
        end
      end
    end
  end
end
