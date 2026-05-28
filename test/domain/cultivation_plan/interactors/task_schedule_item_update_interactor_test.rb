# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemUpdateInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @plan_gateway = mock
          @output_port = mock
          @clock = mock
          @clock.stubs(:now).returns(Time.utc(2026, 6, 1, 12, 0, 0))
          @plan = Entities::CultivationPlanEntity.new(
            id: 2,
            farm_id: 1,
            user_id: 1,
            total_area: 0,
            plan_type: "private"
          )
          @interactor = TaskScheduleItemUpdateInteractor.new(
            output_port: @output_port,
            plan_gateway: @plan_gateway,
            gateway: @gateway,
            clock: @clock
          )
        end

        def amount_snapshot(scheduled_date: Date.new(2026, 5, 1))
          Dtos::TaskScheduleItemAmountSnapshot.new(
            amount: 1.0,
            amount_unit: "kg",
            scheduled_date: scheduled_date
          )
        end

        test "updates item after access check and policy-built attributes" do
          payload = { id: 9, name: "作業A" }
          attrs = { name: "作業A renamed" }

          @plan_gateway.expects(:find_by_id).with(2).returns(@plan)
          @gateway.expects(:find_item_amount_snapshot!).with(2, 9).returns(amount_snapshot)
          @gateway.expects(:update_item_for_plan!).with(2, 9, kind_of(Hash)).returns(payload)
          @output_port.expects(:on_success).with(payload)

          @interactor.call(user_id: 1, plan_id: 2, item_id: 9, attributes: attrs)
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
          @gateway.expects(:find_item_amount_snapshot!).never
          @output_port.expects(:on_not_found)

          @interactor.call(user_id: 1, plan_id: 2, item_id: 9, attributes: { name: "X" })
        end

        test "dispatches record_invalid when gateway update raises RecordInvalid" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @gateway.expects(:find_item_amount_snapshot!).returns(amount_snapshot)
          @gateway.expects(:update_item_for_plan!).raises(
            Domain::Shared::Exceptions::RecordInvalid.new("invalid", errors: { "name" => [ "blank" ] })
          )
          @output_port.expects(:on_record_invalid).with do |errors:, fallback_message:|
            errors["name"].present? && fallback_message == "invalid"
          end

          @interactor.call(user_id: 1, plan_id: 2, item_id: 9, attributes: { name: "" })
        end

        test "dispatches not_found when amount snapshot missing" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @gateway.expects(:find_item_amount_snapshot!).raises(Domain::Shared::Exceptions::RecordNotFound)
          @gateway.expects(:update_item_for_plan!).never
          @output_port.expects(:on_not_found)

          @interactor.call(user_id: 1, plan_id: 2, item_id: 9, attributes: { name: "X" })
        end
      end
    end
  end
end
