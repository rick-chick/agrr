# frozen_string_literal: true

require "test_helper"

class PublicPlanResultsInteractorTest < ActiveSupport::TestCase
  test "call passes read model to on_success when completed" do
    read_model = Domain::CultivationPlan::Dtos::PublicPlanResultsPageReadModel.new(
      plan_id: 5,
      status_completed: true,
      planning_start_date: Date.new(2026, 1, 1),
      planning_end_date: Date.new(2026, 12, 31),
      farm_name: "Farm A",
      total_area: 100.5,
      field_cultivations_count: 2,
      total_cost: 10,
      total_revenue: 20,
      total_profit: 10,
      gantt_cultivation_rows: [ { id: 1 } ],
      gantt_field_rows: [ { id: 2 } ],
      crop_palette_embed: { used_crop_ids: [ 1 ], crops: [ { id: 1, name: "c", variety: "v" } ] },
      show_schedule_warning: false
    )

    gateway = mock
    gateway.expects(:public_plan_results_page_read_model).with(plan_id: 5).returns(read_model)

    output = mock
    output.expects(:on_success).with(read_model)

    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: output,
      gateway: gateway
    ).call(plan_id: 5)
  end

  test "call invokes on_not_found when plan_id is nil" do
    gateway = mock
    gateway.expects(:public_plan_results_page_read_model).never

    output = mock
    output.expects(:on_not_found)

    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: output,
      gateway: gateway
    ).call(plan_id: nil)
  end

  test "call invokes on_not_found when plan_id is not positive" do
    gateway = mock
    gateway.expects(:public_plan_results_page_read_model).never

    output = mock
    output.expects(:on_not_found)

    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: output,
      gateway: gateway
    ).call(plan_id: 0)
  end

  test "call invokes on_not_found when gateway returns nil" do
    gateway = mock
    gateway.expects(:public_plan_results_page_read_model).with(plan_id: 9).returns(nil)

    output = mock
    output.expects(:on_not_found)

    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: output,
      gateway: gateway
    ).call(plan_id: 9)
  end

  test "call invokes redirect_to_optimizing when not completed" do
    read_model = Domain::CultivationPlan::Dtos::PublicPlanResultsPageReadModel.new(
      plan_id: 3,
      status_completed: false,
      planning_start_date: nil,
      planning_end_date: nil,
      farm_name: "F",
      total_area: 1,
      field_cultivations_count: 0,
      total_cost: nil,
      total_revenue: nil,
      total_profit: nil,
      gantt_cultivation_rows: [],
      gantt_field_rows: [],
      crop_palette_embed: { used_crop_ids: [], crops: [] },
      show_schedule_warning: false
    )

    gateway = mock
    gateway.expects(:public_plan_results_page_read_model).with(plan_id: 3).returns(read_model)

    output = mock
    output.expects(:redirect_to_optimizing)

    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: output,
      gateway: gateway
    ).call(plan_id: 3)
  end
end
