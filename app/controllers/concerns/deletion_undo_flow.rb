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
  #
  def schedule_deletion_with_undo(record:, toast_message:, fallback_location:, in_use_message_key: nil, delete_error_message_key:)
    presenter = Presenters::Html::DeletionUndo::DeletionUndoScheduleMastersHtmlPresenter.new(
      view: self,
      fallback_location: fallback_location,
      in_use_message_key: in_use_message_key,
      delete_error_message_key: delete_error_message_key
    )
    input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
      record: record,
      actor: current_user,
      toast_message: toast_message
    )
    CompositionRoot.deletion_undo_schedule_interactor(output_port: presenter).call(input)
  end
end
