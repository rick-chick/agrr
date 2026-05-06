# frozen_string_literal: true

module Presenters
  module Plans
    # DELETE タスクスケジュール項目 — DeletionUndoScheduleInteractor の出力（ApplicationController の削除 Undo 応答）
    class TaskScheduleItemDestroyPresenter < Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort
      def initialize(view:, logger:, fallback_location:)
        @view = view
        @logger = logger
        @fallback_location = fallback_location
        @dual = Presenters::DeletionUndo::DualFormatResponder.new(
          view: view,
          fallback_location: fallback_location,
          logger: logger
        )
      end

      def on_success(entity)
        @dual.render_scheduled_success(entity)
      end

      def on_failure(dto)
        if dto.is_a?(Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto)
          render_failure_dto(dto)
        elsif dto.respond_to?(:message)
          @dual.render_failure(message: dto.message)
        else
          @dual.render_failure(message: dto.to_s)
        end
      end

      private

      def render_failure_dto(dto)
        case dto.reason
        when :forbidden
          @logger&.warn("[Plans::TaskScheduleItemsController] destroy forbidden")
          @dual.render_failure(message: I18n.t("deletion_undo.schedule_forbidden"))
        when :validation_error
          @logger&.warn(
            "[Plans::TaskScheduleItemsController] destroy failed: validation #{dto.detail_message}"
          )
          @dual.render_failure(message: I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed"))
        when :undo_system_error
          @logger&.error(
            "[Plans::TaskScheduleItemsController] undo scheduling error: #{dto.detail_message}"
          )
          @dual.render_failure(
            message: I18n.t(
              "controllers.plans.task_schedule_items.errors.undo_failed",
              message: dto.detail_message
            )
          )
        when :association_in_use
          @logger&.warn(
            "[Plans::TaskScheduleItemsController] destroy blocked: association #{dto.detail_message}"
          )
          @dual.render_failure(message: I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed"))
        else
          @dual.render_failure(
            message: dto.detail_message.presence || I18n.t("controllers.plans.task_schedule_items.errors.cancel_failed")
          )
        end
      end
    end
  end
end
