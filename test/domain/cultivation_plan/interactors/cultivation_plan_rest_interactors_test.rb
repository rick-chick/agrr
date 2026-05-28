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

        def build_interactor
          AddFieldInteractor.new(
            output: @output,
            plan_gateway: @plan_gateway,
            field_mutation_gateway: @field_gateway,
            events_gateway: @events_gateway,
            logger: @logger
          )
        end

        test "dispatches success" do
          snapshot = Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot.new(
            id: 3,
            name: "A",
            area: 1.5
          )
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

          build_interactor.call(
            auth: @auth,
            plan_id: 42,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          )
        end

        test "dispatches not_found when plan missing" do
          @plan_gateway.expects(:find_by_id).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output.expects(:on_not_found)

          build_interactor.call(
            auth: @auth,
            plan_id: 1,
            field_name: "A",
            field_area: "1",
            daily_fixed_cost: nil
          )
        end

      end

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

        test "dispatches field_not_found" do
          @plan_gateway.expects(:find_by_id).with(7).returns(@plan)
          @field_gateway.expects(:find_field).with(plan_id: 7, field_id: 9).returns(nil)
          @output.expects(:on_field_not_found)

          RemoveFieldInteractor.new(
            output: @output,
            plan_gateway: @plan_gateway,
            field_mutation_gateway: @field_gateway,
            events_gateway: @events_gateway,
            logger: @logger
          ).call(auth: @auth, plan_id: 7, field_id_param: "9")
        end
      end

      class RetrieveCultivationPlanInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @read_gateway = mock
          @available_gateway = mock
          @logger = mock
          @logger.stubs(:error)
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)
        end

        test "dispatches success body for public plan" do
          plan = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
            user_id: nil,
            plan_year: 2026,
            plan_name: "p",
            plan_type: "public",
            status: "draft",
            total_area: 0.0,
            planning_start_date: nil,
            planning_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0
          )
          base_snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            available_crop_rows: [],
            farm_region: "jp"
          )
          @read_gateway.expects(:load_snapshot_by_plan_id).with(plan_id: 3).returns(base_snapshot)
          @available_gateway.expects(:list_by_farm_region).with(auth: @auth, farm_region: "jp").returns([])
          @output.expects(:on_success).with do |kwargs|
            s = kwargs[:snapshot]
            s.is_a?(Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot) &&
              s.plan == plan &&
              s.available_crop_rows == []
          end

          RetrieveCultivationPlanInteractor.new(
            output_port: @output,
            workbench_read_gateway: @read_gateway,
            available_crop_rows_gateway: @available_gateway,
            logger: @logger
          ).call(auth: @auth, plan_id: 3)
        end

        test "dispatches not_found when public auth loads private plan row" do
          plan = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
            user_id: 5,
            plan_year: 2026,
            plan_name: "p",
            plan_type: "private",
            status: "draft",
            total_area: 0.0,
            planning_start_date: nil,
            planning_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0
          )
          base_snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            available_crop_rows: [],
            farm_region: "jp"
          )
          @read_gateway.expects(:load_snapshot_by_plan_id).with(plan_id: 3).returns(base_snapshot)
          @output.expects(:on_not_found)
          @available_gateway.expects(:list_by_farm_region).never

          RetrieveCultivationPlanInteractor.new(
            output_port: @output,
            workbench_read_gateway: @read_gateway,
            available_crop_rows_gateway: @available_gateway,
            logger: @logger
          ).call(auth: @auth, plan_id: 3)
        end

        test "dispatches not_found when private auth and workbench rows fail policy" do
          private_auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          plan = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
            user_id: 2,
            plan_year: 2026,
            plan_name: "p",
            plan_type: "private",
            status: "draft",
            total_area: 0.0,
            planning_start_date: nil,
            planning_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0
          )
          base_snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            available_crop_rows: [],
            farm_region: "jp"
          )
          @read_gateway.expects(:load_snapshot_by_plan_id_and_user_id).with(plan_id: 3, user_id: 1).returns(base_snapshot)
          @output.expects(:on_not_found)
          @available_gateway.expects(:list_by_farm_region).never

          RetrieveCultivationPlanInteractor.new(
            output_port: @output,
            workbench_read_gateway: @read_gateway,
            available_crop_rows_gateway: @available_gateway,
            logger: @logger
          ).call(auth: private_auth, plan_id: 3)
        end
      end
    end
  end
end
