# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Dtos
      # スケジュール成功後にクライアントへ渡すフィールド（ルート URL は Presenter が付与）
      class DeletionUndoScheduleSuccessPayloadDto
        attr_reader :undo_token, :undo_deadline, :toast_message, :auto_hide_after, :resource_label,
                    :resource_dom_id

        def initialize(undo_token:, undo_deadline:, toast_message:, auto_hide_after:, resource_label:,
                       resource_dom_id:)
          @undo_token = undo_token
          @undo_deadline = undo_deadline
          @toast_message = toast_message
          @auto_hide_after = auto_hide_after
          @resource_label = resource_label
          @resource_dom_id = resource_dom_id
        end
      end
    end
  end
end
