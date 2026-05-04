# frozen_string_literal: true

# マスタ HTML 削除の薄い委譲のみ（ロジックは lib/deletion_undo/html_master_schedule_invoker.rb）。
module DeletionUndoFlow
  extend ActiveSupport::Concern

  private

  # @param record [ActiveRecord::Base] 削除対象（エッジで既に認可済みの前提。Gateway 側で actor と再照合）
  def schedule_deletion_with_undo(record:, toast_message:, fallback_location:, in_use_message_key: nil, delete_error_message_key:)
    DeletionUndo::HtmlMasterScheduleInvoker.call(
      view: self,
      actor_id: current_user.id,
      record: record,
      toast_message: toast_message,
      fallback_location: fallback_location,
      in_use_message_key: in_use_message_key,
      delete_error_message_key: delete_error_message_key
    )
  end
end
