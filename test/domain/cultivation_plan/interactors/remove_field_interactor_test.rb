# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class RemoveFieldInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @plan_gateway = mock
          @field_gateway = mock
          @events_gateway = mock
          @logger = mock
          @logger.stubs(:error)
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 7,
            farm_id: 1,
            user_id: 1,
            total_area: 0,
            plan_type: "private"
          )
        end

        def interactor
          RemoveFieldInteractor.new(
            output: @output,
            plan_gateway: @plan_gateway,
            field_mutation_gateway: @field_gateway,
            events_gateway: @events_gateway,
            logger: @logger
          )
        end

        def field_row(cultivation_count: 0)
          Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot.new(
            id: 9,
            name: "F",
            area: 1.0,
            cultivation_count: cultivation_count
          )
        end

        def call_interactor(**overrides)
          defaults = { auth: @auth, plan_id: 7, field_id_param: "9" }
          interactor.call(**defaults.merge(overrides))
        end

        test "dispatches success after delete and area refresh" do
          @plan_gateway.expects(:find_by_id).with(7).returns(@plan)
          @field_gateway.expects(:find_field).with(plan_id: 7, field_id: 9).returns(field_row)
          @field_gateway.expects(:count_fields).with(plan_id: 7).returns(2)
          @field_gateway.expects(:delete_field).with(plan_id: 7, field_id: 9)
          @field_gateway.expects(:refresh_total_area).with(plan_id: 7).returns(5.0)
          @events_gateway.expects(:broadcast_field_removed).with(
            plan_id: 7,
            plan_type: "private",
            field_id: 9,
            total_area: 5.0
          )
          @output.expects(:on_success).with(field_id: 9, total_area: 5.0)

          call_interactor
        end

        test "dispatches field_not_found when field row missing" do
          @plan_gateway.expects(:find_by_id).with(7).returns(@plan)
          @field_gateway.expects(:find_field).with(plan_id: 7, field_id: 9).returns(nil)
          @output.expects(:on_field_not_found)
          @field_gateway.expects(:delete_field).never

          call_interactor
        end

        test "dispatches not_found when private auth denies plan" do
          denied = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 7,
            farm_id: 1,
            user_id: 2,
            total_area: 0,
            plan_type: "private"
          )
          @plan_gateway.expects(:find_by_id).returns(denied)
          @field_gateway.expects(:find_field).never
          @output.expects(:on_not_found)

          call_interactor
        end

        test "dispatches cannot_remove_with_cultivations when field has cultivations" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:find_field).returns(field_row(cultivation_count: 1))
          @field_gateway.expects(:count_fields).never
          @output.expects(:on_cannot_remove_with_cultivations)

          call_interactor
        end

        test "dispatches cannot_remove_last_field when only one field remains" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @field_gateway.expects(:find_field).returns(field_row)
          @field_gateway.expects(:count_fields).with(plan_id: 7).returns(1)
          @field_gateway.expects(:delete_field).never
          @output.expects(:on_cannot_remove_last_field)

          call_interactor
        end

        test "dispatches not_found when plan record missing" do
          @plan_gateway.expects(:find_by_id).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output.expects(:on_not_found)

          call_interactor(plan_id: 1, field_id_param: "1")
        end
      end
    end
  end
end
