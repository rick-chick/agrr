# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemScheduleDeletionUndoInteractorTest < DomainLibTestCase
        setup do
          @mutation_output_port = mock("mutation_output_port")
          @mutation_gateway = mock("mutation_gateway")
          @deletion_undo_interactor = mock("deletion_undo_interactor")
          @translator = mock("translator")
          @interactor = TaskScheduleItemScheduleDeletionUndoInteractor.new(
            mutation_output_port: @mutation_output_port,
            mutation_gateway: @mutation_gateway,
            deletion_undo_interactor: @deletion_undo_interactor,
            translator: @translator
          )
        end

        test "schedules deletion undo from gateway row and translator toast" do
          row = {
            resource_type: "TaskScheduleItem",
            resource_id: 42,
            item_name: "灌水"
          }
          expected_toast = "灌水を削除しました"
          @translator.expects(:t).with("plans.task_schedule_items.undo.toast", name: row[:item_name]).returns(expected_toast)

          @mutation_gateway.expects(:deletion_undo_schedule_row_for_item!).with(10, 20, 30).returns(row)
          @deletion_undo_interactor.expects(:call).with do |dto|
            dto.is_a?(Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput) &&
              dto.resource_type == row[:resource_type] &&
              dto.resource_id == row[:resource_id] &&
              dto.actor_id == 10 &&
              dto.toast_message == expected_toast &&
              dto.validate_before_schedule == true
          end

          @interactor.call(user_id: 10, plan_id: 20, item_id: 30)
        end

        test "delegates RecordNotFound to mutation output port" do
          @mutation_gateway.expects(:deletion_undo_schedule_row_for_item!).with(1, 2, 3).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @deletion_undo_interactor.expects(:call).never
          @mutation_output_port.expects(:on_not_found)

          @interactor.call(user_id: 1, plan_id: 2, item_id: 3)
        end
      end
    end
  end
end
