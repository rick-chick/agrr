# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractorTest < ActiveSupport::TestCase
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

      class RemoveFieldInteractorTest < ActiveSupport::TestCase
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

      class RetrieveCultivationPlanInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @gateway = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)
        end

        test "dispatches success body" do
          body = { success: true, data: {}, total_profit: 0, total_revenue: 0, total_cost: 0 }
          @gateway.expects(:build).with(
            auth: @auth,
            plan_id: 3
          ).returns(kind: :success, body: body)
          @output.expects(:on_success).with(body: body)

          RetrieveCultivationPlanInteractor.new(output: @output, workbook_payload_gateway: @gateway).call(
            auth: @auth,
            plan_id: 3
          )
        end
      end

      class ManualPlanAdjustInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @gateway = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
        end

        test "dispatches adjust result" do
          adj = { success: true, message: "ok" }
          @gateway.expects(:execute).with(auth: @auth, plan_id: 2, moves: []).returns(
            kind: :adjust_result, adjust_hash: adj
          )
          @output.expects(:on_adjust).with(result: adj)

          ManualPlanAdjustInteractor.new(output: @output, adjust_gateway: @gateway).call(
            auth: @auth,
            plan_id: 2,
            moves: []
          )
        end

        test "dispatches crop_missing_growth_stages" do
          @gateway.expects(:execute).returns(kind: :crop_missing_growth_stages, crop_name: "X")
          @output.expects(:on_crop_missing_growth_stages).with(crop_name: "X")

          ManualPlanAdjustInteractor.new(output: @output, adjust_gateway: @gateway).call(
            auth: @auth,
            plan_id: 2,
            moves: []
          )
        end
      end
    end
  end
end
