# frozen_string_literal: true

module Adapters::DeletionUndo
  # HTML マスタ削除で Interactor + Presenter を起動するだけの薄いオーケストレーション。
  # ユースケース判断は Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor に集約する。
  module HtmlMasterScheduleInvoker
    module_function

    # record は後方互換用。新規呼び出しは resource_type + resource_id（Interactor に AR を載せない）。
    def call(view:, actor_id:, toast_message:, fallback_location:, in_use_message_key:, delete_error_message_key:, record: nil,
             resource_type: nil, resource_id: nil)
      type_name, rid =
        if record
          [ record.class.name, record.id ]
        elsif resource_type.present? && !resource_id.nil?
          [ resource_type.to_s, resource_id ]
        else
          raise ArgumentError, "Adapters::DeletionUndo::HtmlMasterScheduleInvoker: pass record or resource_type/resource_id"
        end

      presenter = Adapters::DeletionUndo::Presenters::DeletionUndoScheduleMastersHtmlPresenter.new(
        view: view,
        fallback_location: fallback_location,
        in_use_message_key: in_use_message_key,
        delete_error_message_key: delete_error_message_key
      )
      input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput.new(
        resource_type: type_name,
        resource_id: rid,
        actor_id: actor_id,
        toast_message: toast_message
      )
      CompositionRoot.deletion_undo_schedule_interactor(output_port: presenter).call(input)
    end
  end
end
