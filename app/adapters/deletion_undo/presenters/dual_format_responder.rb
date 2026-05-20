# frozen_string_literal: true

module Adapters
  module DeletionUndo
    module Presenters
      # 削除 Undo スケジュール成功・失敗の JSON/HTML 二形式応答（薄い controller メソッドへ委譲）
      class DualFormatResponder
        def initialize(view:, fallback_location:, logger: nil)
          @view = view
          @fallback_location = fallback_location
          @logger = logger || (view.respond_to?(:logger) ? view.logger : nil)
        end

        def render_scheduled_success(scheduled_undo)
          snapshot = Domain::DeletionUndo::ScheduledUndoSnapshot.from(scheduled_undo)

          if snapshot.undo_token.blank?
            @logger&.error(
              "[DeletionUndo] Missing undo_token for #{snapshot.resource_type || 'unknown'}#" \
              "#{snapshot.resource_id || 'unknown'}"
            )
            render_failure(message: "Undo token could not be generated", status: :internal_server_error)
            return
          end

          resource_dom_id = build_resource_dom_id(snapshot)
          dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleSuccessOutput.new(
            undo_token: snapshot.undo_token,
            undo_deadline: snapshot.metadata["undo_deadline"],
            toast_message: snapshot.toast_message,
            auto_hide_after: snapshot.auto_hide_after,
            resource_label: snapshot.metadata["resource_label"],
            resource_dom_id: resource_dom_id
          )

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

        def render_failure(message:, status: :unprocessable_entity)
          @view.render_deletion_undo_dual_failure(
            json: { error: message },
            html_alert: message,
            fallback_location: @fallback_location,
            status: status
          )
        end

        private

        def build_resource_dom_id(snapshot)
          stored = snapshot.metadata["resource_dom_id"]
          return stored if stored.present?
          return nil unless snapshot.resource_type.present? && snapshot.resource_id.present?

          [snapshot.resource_type.to_s.demodulize.underscore, snapshot.resource_id.to_s].join("_")
        end
      end
    end
  end
end
