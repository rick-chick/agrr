# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 作業予定削除の Undo スケジュール（ゲートウェイでスコープ検証し、DeletionUndo に委譲）
      class TaskScheduleItemScheduleDeletionUndoInteractor
        def initialize(json_output_port:, mutation_gateway:, deletion_undo_interactor:, translator:)
          @json_output_port = json_output_port
          @mutation_gateway = mutation_gateway
          @deletion_undo_interactor = deletion_undo_interactor
          @translator = translator
        end

        def call(user_id:, plan_id:, item_id:)
          row = @mutation_gateway.deletion_undo_schedule_row_for_item!(user_id, plan_id, item_id)
          input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: row[:resource_type],
            resource_id: row[:resource_id],
            actor_id: user_id,
            toast_message: @translator.t("plans.task_schedule_items.undo.toast", name: row[:item_name]),
            validate_before_schedule: true
          )
          @deletion_undo_interactor.call(input)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @json_output_port.on_not_found
        end
      end
    end
  end
end
