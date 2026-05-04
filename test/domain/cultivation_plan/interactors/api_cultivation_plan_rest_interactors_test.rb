# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class ApiAddFieldInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @flow = mock
          @host = mock
        end

        test "dispatches success" do
          pf = mock
          pf.stubs(:id).returns(3)
          pf.stubs(:name).returns("A")
          pf.stubs(:area).returns(1.5)
          @flow.expects(:add_field_run).returns(kind: :success, plan_field: pf, total_area: 10.0)
          @output.expects(:on_success).with(field_id: 3, name: "A", area: 1.5, total_area: 10.0)

          ApiAddFieldInteractor.new(output: @output, flow: @flow).call(
            host: @host,
            load_plan: -> {},
            field_name: "A",
            field_area: "1.5",
            daily_fixed_cost: nil
          )
        end

        test "dispatches not_found" do
          @flow.expects(:add_field_run).returns(kind: :not_found)
          @output.expects(:on_not_found)

          ApiAddFieldInteractor.new(output: @output, flow: @flow).call(
            host: @host,
            load_plan: -> {},
            field_name: "A",
            field_area: "1",
            daily_fixed_cost: nil
          )
        end
      end

      class ApiRemoveFieldInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @host = mock }

        test "dispatches field_not_found" do
          @flow.expects(:remove_field_run).returns(kind: :field_not_found)
          @output.expects(:on_field_not_found)

          ApiRemoveFieldInteractor.new(output: @output, flow: @flow).call(
            host: @host, load_plan: -> {}, field_id_param: "9"
          )
        end
      end

      class ApiPlanDataInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @host = mock }

        test "dispatches success body" do
          body = { success: true, data: {}, total_profit: 0, total_revenue: 0, total_cost: 0 }
          @flow.expects(:data_run).returns(kind: :success, body: body)
          @output.expects(:on_success).with(body: body)

          ApiPlanDataInteractor.new(output: @output, flow: @flow).call(host: @host, load_plan: -> {})
        end
      end

      class ApiPlanAdjustInteractorTest < ActiveSupport::TestCase
        setup { @output = mock; @flow = mock; @host = mock }

        test "dispatches adjust result" do
          adj = { success: true, message: "ok" }
          @flow.expects(:adjust_run).returns(kind: :adjust_result, adjust_hash: adj)
          @output.expects(:on_adjust).with(result: adj)

          ApiPlanAdjustInteractor.new(output: @output, flow: @flow).call(
            host: @host, load_plan: -> {}, moves_raw: []
          )
        end

        test "dispatches crop_missing_growth_stages" do
          @flow.expects(:adjust_run).returns(kind: :crop_missing_growth_stages, crop_name: "X")
          @output.expects(:on_crop_missing_growth_stages).with(crop_name: "X")

          ApiPlanAdjustInteractor.new(output: @output, flow: @flow).call(
            host: @host, load_plan: -> {}, moves_raw: []
          )
        end
      end
    end
  end
end
