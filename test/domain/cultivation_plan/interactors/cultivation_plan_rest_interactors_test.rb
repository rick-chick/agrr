# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @flow = mock
          @plan_loader = mock
        end

        test "dispatches success" do
          pf = mock
          pf.stubs(:id).returns(3)
          pf.stubs(:name).returns("A")
          pf.stubs(:area).returns(1.5)
          @flow.expects(:add_field_run).with(
            plan_loader: @plan_loader,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          ).returns(kind: :success, plan_field: pf, total_area: 10.0)
          @output.expects(:on_success).with(field_id: 3, name: "A", area: 1.5, total_area: 10.0)

          AddFieldInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          )
        end

        test "dispatches not_found" do
          @flow.expects(:add_field_run).with(
            plan_loader: @plan_loader,
            field_name: "A",
            field_area: "1",
            daily_fixed_cost: nil
          ).returns(kind: :not_found)
          @output.expects(:on_not_found)

          AddFieldInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            field_name: "A",
            field_area: "1",
            daily_fixed_cost: nil
          )
        end
      end

      class RemoveFieldInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @plan_loader = mock }

        test "dispatches field_not_found" do
          @flow.expects(:remove_field_run).with(plan_loader: @plan_loader, field_id_param: "9").returns(kind: :field_not_found)
          @output.expects(:on_field_not_found)

          RemoveFieldInteractor.new(output: @output, flow: @flow).call(plan_loader: @plan_loader, field_id_param: "9")
        end
      end

      class RetrieveCultivationPlanInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @plan_loader = mock }

        test "dispatches success body" do
          body = { success: true, data: {}, total_profit: 0, total_revenue: 0, total_cost: 0 }
          @flow.expects(:data_run).with(plan_loader: @plan_loader).returns(kind: :success, body: body)
          @output.expects(:on_success).with(body: body)

          RetrieveCultivationPlanInteractor.new(output: @output, flow: @flow).call(plan_loader: @plan_loader)
        end
      end

      class ManualPlanAdjustInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @plan_loader = mock }

        test "dispatches adjust result" do
          adj = { success: true, message: "ok" }
          @flow.expects(:adjust_run).with(plan_loader: @plan_loader, moves_raw: []).returns(kind: :adjust_result, adjust_hash: adj)
          @output.expects(:on_adjust).with(result: adj)

          ManualPlanAdjustInteractor.new(output: @output, flow: @flow).call(plan_loader: @plan_loader, moves_raw: [])
        end

        test "dispatches crop_missing_growth_stages" do
          @flow.expects(:adjust_run).with(plan_loader: @plan_loader, moves_raw: []).returns(kind: :crop_missing_growth_stages, crop_name: "X")
          @output.expects(:on_crop_missing_growth_stages).with(crop_name: "X")

          ManualPlanAdjustInteractor.new(output: @output, flow: @flow).call(plan_loader: @plan_loader, moves_raw: [])
        end
      end
    end
  end
end
