# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @plan_gateway = mock
          @field_gateway = mock
          @events_gateway = mock
          @logger = mock
          @logger.stubs(:error)
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 42,
            farm_id: 1,
            user_id: 1,
            total_area: 0,
            plan_type: "private"
          )
        end

        def interactor
          AddFieldInteractor.new(
            output: @output,
            plan_gateway: @plan_gateway,
            field_mutation_gateway: @field_gateway,
            events_gateway: @events_gateway,
            logger: @logger
          )
        end

        def field_snapshot(id: 3, name: "A", area: 1.5)
          Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot.new(
            id: id,
            name: name,
            area: area
          )
        end

        def call_interactor(**overrides)
          defaults = {
            auth: @auth,
            plan_id: 42,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          }
          interactor.call(**defaults.merge(overrides))
        end

        test "dispatches success with broadcast and refreshed total area" do
          snapshot = field_snapshot
          @plan_gateway.expects(:find_by_id).with(42).returns(@plan)
          @field_gateway.expects(:count_fields).with(plan_id: 42).returns(1)
          @field_gateway.expects(:create_field).with(
            plan_id: 42,
            field_name: "A",
            field_area: 1.5,
            daily_fixed_cost: nil
          ).returns(snapshot)
          @field_gateway.expects(:refresh_total_area).with(plan_id: 42).returns(10.0)
          @events_gateway.expects(:broadcast_field_added).with do |kwargs|
            kwargs[:plan_id] == 42 &&
              kwargs[:plan_type] == "private" &&
              kwargs[:total_area] == 10.0 &&
              kwargs[:field_snapshot].is_a?(Domain::CultivationPlan::Dtos::FieldOptimizationEventSnapshot)
          end
          @output.expects(:on_success).with(field_id: 3, name: "A", area: 1.5, total_area: 10.0)

          call_interactor
        end

        test "dispatches not_found when plan missing" do
          @plan_gateway.expects(:find_by_id).raises(Domain::Shared::Exceptions::RecordNotFound)
          @field_gateway.expects(:count_fields).never
          @output.expects(:on_not_found)

          call_interactor(plan_id: 1)
        end

        test "dispatches not_found when private auth denies plan" do
          denied = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 1,
            farm_id: 1,
            user_id: 2,
            total_area: 0,
            plan_type: "private"
          )
          @plan_gateway.expects(:find_by_id).with(1).returns(denied)
          @field_gateway.expects(:count_fields).never
          @output.expects(:on_not_found)

          call_interactor(plan_id: 1)
        end

        test "dispatches invalid_field_params when area is not positive" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:count_fields).never
          @output.expects(:on_invalid_field_params)

          call_interactor(field_area: "0")
        end

        test "dispatches max_fields_limit when field count at cap" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:count_fields).with(plan_id: 42).returns(
            Domain::CultivationPlan::FieldsAllocation::MAX_FIELDS
          )
          @field_gateway.expects(:create_field).never
          @output.expects(:on_max_fields_limit)

          call_interactor
        end

        test "dispatches record_invalid when gateway raises RecordInvalid" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:count_fields).returns(1)
          @field_gateway.expects(:create_field).raises(
            Domain::Shared::Exceptions::RecordInvalid.new("bad field")
          )
          @logger.expects(:error).with(includes("bad field"))
          @output.expects(:on_record_invalid).with(message: "bad field")

          call_interactor
        end

        test "dispatches unexpected on StandardError" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:count_fields).raises(StandardError.new("boom"))
          @logger.expects(:error).with(includes("boom"))
          @output.expects(:on_unexpected).with(message: "boom")

          call_interactor
        end
      end
    end
  end
end
