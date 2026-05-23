# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @gateway = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
        end

        test "dispatches success" do
          pf = mock
          pf.stubs(:id).returns(3)
          pf.stubs(:name).returns("A")
          pf.stubs(:area).returns(1.5)
          @gateway.expects(:add_field).with(
            auth: @auth,
            plan_id: 42,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          ).returns(kind: :success, plan_field: pf, total_area: 10.0)
          @output.expects(:on_success).with(field_id: 3, name: "A", area: 1.5, total_area: 10.0)

          AddFieldInteractor.new(output: @output, field_mutation_gateway: @gateway).call(
            auth: @auth,
            plan_id: 42,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          )
        end

        test "dispatches not_found" do
          @gateway.expects(:add_field).returns(kind: :not_found)
          @output.expects(:on_not_found)

          AddFieldInteractor.new(output: @output, field_mutation_gateway: @gateway).call(
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
          @gateway = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
        end

        test "dispatches field_not_found" do
          @gateway.expects(:remove_field).with(
            auth: @auth,
            plan_id: 7,
            field_id_param: "9"
          ).returns(kind: :field_not_found)
          @output.expects(:on_field_not_found)

          RemoveFieldInteractor.new(output: @output, field_mutation_gateway: @gateway).call(
            auth: @auth,
            plan_id: 7,
            field_id_param: "9"
          )
        end
      end

      class RetrieveCultivationPlanInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @gateway = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)
        end

        test "dispatches success body" do
          plan = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
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
          snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            available_crop_rows: []
          )
          @gateway.expects(:find_by_plan_id).with(
            auth: @auth,
            plan_id: 3
          ).returns(kind: :success, snapshot: snapshot)
          @output.expects(:on_success).with(snapshot: snapshot)

          RetrieveCultivationPlanInteractor.new(output_port: @output, workbench_payload_gateway: @gateway).call(
            auth: @auth,
            plan_id: 3
          )
        end
      end

      class PlanAllocationAdjustGrowthReadTest < DomainLibTestCase
        setup do
          @output = mock
          @growth = mock
          @plan_gateway = mock
          @plan_gateway.stubs(:end_adjust_session!)
          @logger = mock
          @logger.stubs(:info)
          @logger.stubs(:error)
          @clock = mock
          @clock.stubs(:now).returns(Time.utc(2026, 1, 1))
          @translator = mock
          @translator.stubs(:translate).returns("translated")
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @interactor = PlanAllocationAdjustInteractor.new(
            output_port: @output,
            logger: @logger,
            translator: @translator,
            clock: @clock,
            plan_gateway: @plan_gateway,
            weather_prediction_gateway: mock,
            agrr_adjust_gateway: mock,
            save_adjusted_gateway: mock,
            optimization_events_gateway: mock,
            adjust_plan_growth_read_gateway: @growth,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new
          )
        end

        test "runs adjust after growth read passes" do
          row = Domain::CultivationPlan::Dtos::CultivationPlanAdjustCropGrowthRow.new(
            crop_name: "C",
            growth_stage_count: 1
          )
          @growth.expects(:load).with(auth: @auth, plan_id: 2).returns(
            kind: :success,
            crop_rows: [row]
          )
          @output.expects(:on_success).with do |output:|
            output.skipped == true && output.message.include?("調整不要")
          end

          @interactor.call(
            Dtos::PlanAllocationAdjustInput.new(
              plan_id: 2,
              moves: [],
              auth: @auth
            )
          )
        end

        test "dispatches crop_missing_growth_stages as failure" do
          row = Domain::CultivationPlan::Dtos::CultivationPlanAdjustCropGrowthRow.new(
            crop_name: "X",
            growth_stage_count: 0
          )
          @growth.expects(:load).returns(kind: :success, crop_rows: [row])
          @translator.expects(:translate).with(
            "api.errors.cultivation_plan.crop_missing_growth_stages",
            crop_name: "X"
          ).returns("missing stages")
          @output.expects(:on_failure).with do |failure:|
            failure.kind == Dtos::PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES &&
              failure.message == "missing stages"
          end
          @output.expects(:on_success).never

          @interactor.call(
            Dtos::PlanAllocationAdjustInput.new(
              plan_id: 2,
              moves: [],
              auth: @auth
            )
          )
        end
      end
    end
  end
end
