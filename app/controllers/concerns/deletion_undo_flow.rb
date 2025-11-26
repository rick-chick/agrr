# frozen_string_literal: true

module DeletionUndoFlow
  extend ActiveSupport::Concern

  private

  # 共通の削除＋Undoフロー
  #
  # @param record [ActiveRecord::Base] 削除対象レコード
  # @param toast_message [String] Undoトーストに表示するメッセージ
  # @param fallback_location [String] HTMLでのリダイレクト先パス
  # @param in_use_message_key [String, nil] 使用中で削除できない場合のI18nキー
  # @param delete_error_message_key [String] その他削除エラー時のI18nキー
  def schedule_deletion_with_undo(record:, toast_message:, fallback_location:, in_use_message_key: nil, delete_error_message_key:)
    event = DeletionUndo::Manager.schedule(
      record: record,
      actor: current_user,
      toast_message: toast_message
    )

    render_deletion_undo_response(
      event,
      fallback_location: fallback_location
    )
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    message =
      if in_use_message_key
        I18n.t(in_use_message_key)
      else
        I18n.t(delete_error_message_key, message: I18n.t('errors.messages.restrict_dependent_destroy'))
      end

    render_deletion_failure(
      message: message,
      fallback_location: fallback_location
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t(delete_error_message_key, message: e.message),
      fallback_location: fallback_location
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t(delete_error_message_key, message: e.message),
      fallback_location: fallback_location
    )
  end
end

