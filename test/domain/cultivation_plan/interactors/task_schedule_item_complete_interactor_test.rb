# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCompleteInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @plan_gateway = mock
          @output_port = mock
          @clock = mock
          @now = Time.utc(2026, 3, 1, 12, 0, 0)
          @clock.stubs(:today).returns(Date.new(2026, 3, 1))
          @clock.stubs(:now).returns(@now)
          @plan = Entities::CultivationPlanEntity.new(
            id: 2,
            farm_id: 1,
            user_id: 1,
            total_area: 0,
            plan_type: "private"
          )
          @interactor = TaskScheduleItemCompleteInteractor.new(
            output_port: @output_port,
            plan_gateway: @plan_gateway,
            gateway: @gateway,
            clock: @clock
          )
        end

        test "completes item after private plan access check" do
          payload = { id: 9, status: "completed" }
          completion_params = { actual_date: "2026-04-10", notes: "実施メモ" }

          @plan_gateway.expects(:find_by_id).with(2).returns(@plan)
          @gateway.expects(:complete_item_for_plan!).with(
            2,
            9,
            actual_date: Date.new(2026, 4, 10),
            actual_notes: "実施メモ",
            completed_at: @now
          ).returns(payload)
          @output_port.expects(:on_success).with(payload)

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            item_id: 9,
            completion_params: completion_params
          )
        end

        test "dispatches not_found when private plan access denied" do
          other_plan = Entities::CultivationPlanEntity.new(
            id: 2,
            farm_id: 1,
            user_id: 99,
            total_area: 0,
            plan_type: "private"
          )

          @plan_gateway.expects(:find_by_id).with(2).returns(other_plan)
          @gateway.expects(:complete_item_for_plan!).never
          @output_port.expects(:on_not_found)

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            item_id: 9,
            completion_params: {}
          )
        end

        test "dispatches record_invalid when completion params have invalid date" do
          @plan_gateway.expects(:find_by_id).with(2).returns(@plan)
          @gateway.expects(:complete_item_for_plan!).never
          @output_port.expects(:on_record_invalid).with do |errors:, fallback_message:|
            errors["actual_date"].present? && fallback_message.present?
          end

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            item_id: 9,
            completion_params: { actual_date: "bogus" }
          )
        end

        test "dispatches record_invalid when gateway complete raises RecordInvalid" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @gateway.expects(:complete_item_for_plan!).raises(
            Domain::Shared::Exceptions::RecordInvalid.new(
              "invalid",
              errors: { "actual_date" => ["blank"] }
            )
          )
          @output_port.expects(:on_record_invalid).with do |errors:, fallback_message:|
            errors["actual_date"].present? && fallback_message == "invalid"
          end

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            item_id: 9,
            completion_params: {}
          )
        end

        test "dispatches not_found when gateway complete raises RecordNotFound" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @gateway.expects(:complete_item_for_plan!).raises(
            Domain::Shared::Exceptions::RecordNotFound
          )
          @output_port.expects(:on_not_found)

          @interactor.call(
            user_id: 1,
            plan_id: 2,
            item_id: 9,
            completion_params: {}
          )
        end
      end
    end
  end
end
