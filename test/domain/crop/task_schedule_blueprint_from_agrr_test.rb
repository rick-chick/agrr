# frozen_string_literal: true

require "domain_lib_test_helper"

class DomainCropTaskScheduleBlueprintFromAgrrTest < DomainLibTestCase
  test "fertilizer_row assigns basal then topdress task types from index" do
    types = Domain::AgriculturalTask::Constants::ScheduleItemTypes
    first = Domain::Crop::TaskScheduleBlueprintFromAgrr.fertilizer_row(
      crop_id: 1,
      entry: { "task_id" => "1", "stage_order" => 0 },
      index: 0,
      agricultural_task_id: 10
    )
    second = Domain::Crop::TaskScheduleBlueprintFromAgrr.fertilizer_row(
      crop_id: 1,
      entry: { "task_id" => "2", "stage_order" => 1 },
      index: 1,
      agricultural_task_id: 11
    )

    assert_equal types::BASAL_FERTILIZATION, first[:task_type]
    assert_equal types::TOPDRESS_FERTILIZATION, second[:task_type]
    assert_equal "基肥", first[:stage_name]
    assert_equal "追肥", second[:stage_name]
  end

  test "general_row uses field_work task type" do
    types = Domain::AgriculturalTask::Constants::ScheduleItemTypes
    row = Domain::Crop::TaskScheduleBlueprintFromAgrr.general_row(
      crop_id: 5,
      task: { "task_id" => "9", "stage_order" => 1, "gdd_trigger" => 0 },
      agricultural_task_id: 9
    )

    assert_equal types::FIELD_WORK, row[:task_type]
    assert_equal "agrr_schedule", row[:source]
    assert_equal 5, row[:crop_id]
  end

  test "integer_value and decimal_value coerce API-like strings" do
    m = Domain::Crop::TaskScheduleBlueprintFromAgrr
    assert_equal 42, m.integer_value("42")
    assert_nil m.integer_value("x")
    assert_equal BigDecimal("1.5"), m.decimal_value("1.5")
  end
end
