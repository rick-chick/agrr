# frozen_string_literal: true

module Presenters
  module Plans
    # DELETE タスクスケジュール項目 — DeletionUndoScheduleInteractor の出力（DeletionUndoResponder）
    class TaskScheduleItemDestroyPresenter < Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort
      def initialize(view:, logger:, fallback_location:)
        @view = view
        @logger = logger
        @fallback_location = fallback_location
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
          render_failure_dto(dto)
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

      private

      def render_failure_dto(dto)
        case dto.reason
        when :forbidden
          @logger&.warn("[Plans::TaskScheduleItemsController] destroy forbidden")
          @view.send(
            :render_deletion_failure,
            message: I18n.t("deletion_undo.schedule_forbidden"),
            fallback_location: @fallback_location
          )
        when :validation_error
          @logger&.warn(
            "[Plans::TaskScheduleItemsController] destroy failed: validation #{dto.detail_message}"
          )
          @view.send(
            :render_deletion_failure,
            message: I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed"),
            fallback_location: @fallback_location
          )
        when :undo_system_error
          @logger&.error(
            "[Plans::TaskScheduleItemsController] undo scheduling error: #{dto.detail_message}"
          )
          @view.send(
            :render_deletion_failure,
            message: I18n.t(
              "controllers.plans.task_schedule_items.errors.undo_failed",
              message: dto.detail_message
            ),
            fallback_location: @fallback_location
          )
        when :association_in_use
          @logger&.warn(
            "[Plans::TaskScheduleItemsController] destroy blocked: association #{dto.detail_message}"
          )
          @view.send(
            :render_deletion_failure,
            message: I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed"),
            fallback_location: @fallback_location
          )
        else
          @view.send(
            :render_deletion_failure,
            message: dto.detail_message.presence || I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed"),
            fallback_location: @fallback_location
          )
        end
      end
    end
  end
end
