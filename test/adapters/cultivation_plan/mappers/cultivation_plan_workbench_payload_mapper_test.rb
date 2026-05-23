# frozen_string_literal: true

require "test_helper"

class CultivationPlanWorkbenchPayloadMapperTest < ActiveSupport::TestCase
  test "to_json_body builds REST workbench envelope from snapshot" do
    plan = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
      id: 1,
      plan_year: 2026,
      plan_name: "p",
      plan_type: "private",
      status: "draft",
      total_area: 1.0,
      planning_start_date: Date.new(2026, 1, 1),
      planning_end_date: Date.new(2026, 12, 31),
      total_profit: 10.0,
      total_revenue: 20.0,
      total_cost: 10.0
    )
    snapshot = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot.new(
      plan: plan,
      fields: [],
      crops: [],
      cultivations: [],
      available_crop_rows: []
    )

    body = Adapters::CultivationPlan::Mappers::CultivationPlanWorkbenchPayloadMapper.to_json_body(snapshot)

    assert_equal true, body[:success]
    assert_equal 1, body[:data][:id]
    assert_equal 10.0, body[:total_profit]
  end
end
