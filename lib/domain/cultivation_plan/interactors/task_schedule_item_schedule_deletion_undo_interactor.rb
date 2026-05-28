# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 作業予定削除の Undo スケジュール（ゲートウェイでスコープ検証し、DeletionUndo に委譲）
      class TaskScheduleItemScheduleDeletionUndoInteractor
        def initialize(mutation_output_port:, plan_gateway:, mutation_gateway:, deletion_undo_interactor:, translator:)
          @mutation_output_port = mutation_output_port
          @plan_gateway = plan_gateway
          @mutation_gateway = mutation_gateway
          @deletion_undo_interactor = deletion_undo_interactor
          @translator = translator
        end

        def call(user_id:, plan_id:, item_id:)
          unless TaskSchedulePrivatePlanAccess.access_allowed?(
            plan_gateway: @plan_gateway, plan_id: plan_id, user_id: user_id
          )
            @mutation_output_port.on_not_found
            return
          end

          row = @mutation_gateway.deletion_undo_schedule_row_for_item!(plan_id, item_id)
          input = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput.new(
            resource_type: row[:resource_type],
            resource_id: row[:resource_id],
            actor_id: user_id,
            toast_message: @translator.t("plans.task_schedule_items.undo.toast", name: row[:item_name]),
            validate_before_schedule: true
          )
          @deletion_undo_interactor.call(input)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @mutation_output_port.on_not_found
        end
      end
    end
  end
end
