# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldCultivationCreateAttrsTest < DomainLibTestCase
  Dtos = Domain::CultivationPlan::Dtos

  test "to_active_record_attributes nests optimization snapshot" do
    allocation = { "crop_id" => "9", "area_used" => 10.0 }
    opt = Dtos::FieldCultivationOptimizationPersist.new(
      allocation_id: 11,
      expected_revenue: 100.0,
      profit: 40.0,
      raw_allocation_document: allocation
    )
    dto = Dtos::FieldCultivationCreateAttrs.new(
      cultivation_plan_field_id: 1,
      cultivation_plan_crop_id: 2,
      area: 10.0,
      start_date: Date.new(2024, 4, 1),
      completion_date: Date.new(2024, 6, 1),
      cultivation_days: 60,
      estimated_cost: 60.0,
      status: :completed,
      optimization_result: opt
    )

    h = dto.to_active_record_attributes
    assert_equal 1, h[:cultivation_plan_field_id]
    assert_equal({ "crop_id" => "9", "area_used" => 10.0 }, h[:optimization_result][:raw])
    assert_equal 100.0, h[:optimization_result][:expected_revenue]
  end

  test "optimization_apply_attrs maps keys for update" do
    dto = Dtos::OptimizationApplyAttrs.new(
      total_profit: 1.0,
      total_revenue: 2.0,
      total_cost: 3.0,
      optimization_time: Time.utc(2026, 1, 1),
      algorithm_used: "greedy",
      is_optimal: true,
      optimization_summary: "{}"
    )
    h = dto.to_active_record_attributes
    assert_equal 1.0, h[:total_profit]
    assert_equal "{}", h[:optimization_summary]
    assert_equal true, h[:is_optimal]
  end
end
