# frozen_string_literal: true

module Presenters
  module DeletionUndo
    # 削除 Undo スケジュール成功・失敗の JSON/HTML 二形式応答（薄い controller メソッドへ委譲）
    class DualFormatResponder
      def initialize(view:, fallback_location:, logger: nil)
        @view = view
        @fallback_location = fallback_location
        @logger = logger || (view.respond_to?(:logger) ? view.logger : nil)
      end

      def render_scheduled_success(scheduled_undo)
        snapshot = Domain::DeletionUndo::ScheduledUndoSnapshot.from(scheduled_undo)
        Domain::DeletionUndo::Interactors::DeletionUndoScheduleSuccessPayloadInteractor.new(
          output_port: ScheduleSuccessPayloadOutputAdapter.new(view: @view, fallback_location: @fallback_location),
          logger: @logger
        ).call(snapshot)
      end

      def render_failure(message:, status: :unprocessable_entity)
        @view.render_deletion_undo_dual_failure(
          json: { error: message },
          html_alert: message,
          fallback_location: @fallback_location,
          status: status
        )
      end

      # Presenter 層: DTO → ルートヘルパを含む JSON / HTML フラッシュ
      class ScheduleSuccessPayloadOutputAdapter < Domain::DeletionUndo::Ports::DeletionUndoScheduleSuccessPayloadOutputPort
        def initialize(view:, fallback_location:)
          @view = view
          @fallback_location = fallback_location
        end

        def on_success(dto)
          json = {
            undo_token: dto.undo_token,
            undo_deadline: dto.undo_deadline,
            toast_message: dto.toast_message,
            undo_path: @view.undo_deletion_path(undo_token: dto.undo_token),
            auto_hide_after: dto.auto_hide_after,
            resource: dto.resource_label,
            redirect_path: @fallback_location,
            resource_dom_id: dto.resource_dom_id
          }
          notice = I18n.t("deletion_undo.redirect_notice", resource: dto.resource_label)
          @view.render_deletion_undo_dual_success(
            json: json,
            html_notice: notice,
            fallback_location: @fallback_location,
            status: :ok
          )
        end

        def on_failure(dto)
          message =
            case dto.reason
            when :missing_undo_token
              "Undo token could not be generated"
            else
              dto.reason.to_s
            end
          @view.render_deletion_undo_dual_failure(
            json: { error: message },
            html_alert: message,
            fallback_location: @fallback_location,
            status: dto.http_status
          )
        end
      end
    end
  end
end
