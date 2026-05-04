# frozen_string_literal: true

module DeletionUndo
  # HTML マスタ削除で Interactor + Presenter を起動するだけの薄いオーケストレーション。
  # ユースケース判断は Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor に集約する。
  module HtmlMasterScheduleInvoker
    module_function

    def call(view:, actor_id:, record:, toast_message:, fallback_location:, in_use_message_key:, delete_error_message_key:)
      presenter = Presenters::Html::DeletionUndo::DeletionUndoScheduleMastersHtmlPresenter.new(
        view: view,
        fallback_location: fallback_location,
        in_use_message_key: in_use_message_key,
        delete_error_message_key: delete_error_message_key
      )
      input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
        resource_type: record.class.name,
        resource_id: record.id,
        actor_id: actor_id,
        toast_message: toast_message
      )
      CompositionRoot.deletion_undo_schedule_interactor(output_port: presenter).call(input)
    end
  end
end
