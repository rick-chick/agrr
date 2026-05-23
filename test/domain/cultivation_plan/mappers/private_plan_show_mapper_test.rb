# frozen_string_literal: true

require "domain_lib_test_helper"

class PrivatePlanShowMapperTest < DomainLibTestCase
  test "call builds show dto and gantt row hashes from detail reads" do
    fc_read = Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::FieldCultivationRead.new(
      id: 1,
      cultivation_plan_field_id: 2,
      field_display_name: "North",
      cultivation_plan_crop_id: 3,
      crop_display_name: "Tomato",
      start_date: Date.new(2025, 3, 1),
      completion_date: Date.new(2025, 6, 1),
      cultivation_days: 90,
      area: 10.5,
      estimated_cost: 100,
      optimization_profit: 42
    )
    field_read = Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::PlanFieldRead.new(
      id: 2,
      name: "North",
      area: 50
    )
    detail = Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail.new(
      id: 99,
      display_name: "P1",
      farm_display_name: "F1",
      total_area: 200,
      field_cultivations_count: 1,
      cultivation_plan_fields_count: 1,
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2025, 12, 31),
      status: "pending",
      field_cultivations: [ fc_read ],
      cultivation_plan_fields: [ field_read ],
      palette_used_crop_ids: [],
      palette_crops: []
    )

    dto = Domain::CultivationPlan::Mappers::PrivatePlanShowMapper.call(detail)

    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanShow, dto
    assert_equal 99, dto.id
    assert_equal "pending", dto.status
    assert_equal 1, dto.gantt_cultivation_rows.size
    row = dto.gantt_cultivation_rows.first
    assert_equal 1, row[:id]
    assert_equal 2, row[:field_id]
    assert_equal "North", row[:field_name]
    assert_equal 42, row[:profit]
    assert_equal 1, dto.gantt_field_rows.size
    assert_equal 2, dto.gantt_field_rows.first[:id]
    assert_equal "North", dto.gantt_field_rows.first[:name]
  end
end
