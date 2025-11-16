require "test_helper"

class AgrrOptimizationDiffSaveTest < ActiveSupport::TestCase
  class Saver
    include AgrrOptimization
  end

  def setup
    @plan = create(:cultivation_plan)
    @field1 = create(:cultivation_plan_field, cultivation_plan: @plan)
    @field2 = create(:cultivation_plan_field, cultivation_plan: @plan)

    @crop1 = create(:crop, :with_stages)
    @crop2 = create(:crop, :with_stages)
    @plan_crop1 = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop1)
    @plan_crop2 = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop2)

    @fc_keep = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop1,
      start_date: Date.current,
      completion_date: Date.current + 10,
      area: 10.0,
      estimated_cost: 1000.0,
      status: 'pending'
    )

    @fc_delete = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field2,
      cultivation_plan_crop: @plan_crop2,
      start_date: Date.current + 1,
      completion_date: Date.current + 5,
      area: 5.0,
      estimated_cost: 500.0,
      status: 'pending'
    )

    # 削除対象のスケジュール（null化されることを確認）
    @ts_for_delete = create(:task_schedule, cultivation_plan: @plan, field_cultivation: @fc_delete)
    create(:task_schedule_item, task_schedule: @ts_for_delete)

    @saver = Saver.new
  end

  test "diff save updates existing, creates new, and nullifies schedules for deleted" do
    # 望ましい結果（@fc_keep は更新、@fc_delete は消える、新規1件を作成）
    result = {
      summary: { "ok" => true },
      total_profit: 123.0,
      total_revenue: 456.0,
      total_cost: 333.0,
      optimization_time: 1.23,
      algorithm_used: "test",
      is_optimal: true,
      field_schedules: [
        {
          'field_id' => @field1.id,
          'allocations' => [
            {
              'allocation_id' => @fc_keep.id, # 既存 -> 更新
              'crop_id' => @crop1.id.to_s,
              'area_used' => 20.0, # 変更
              'total_cost' => 1500.0, # 変更
              'expected_revenue' => 3000.0,
              'profit' => 1500.0,
              'accumulated_gdd' => 100.0,
              'start_date' => (Date.current + 2).to_s, # 変更
              'completion_date' => (Date.current + 12).to_s
            },
            {
              'allocation_id' => nil, # 新規 -> 作成
              'crop_id' => @crop2.id.to_s,
              'area_used' => 7.5,
              'total_cost' => 700.0,
              'expected_revenue' => 2000.0,
              'profit' => 1300.0,
              'accumulated_gdd' => 55.0,
              'start_date' => (Date.current + 1).to_s,
              'completion_date' => (Date.current + 8).to_s
            }
          ]
        }
      ]
    }

    assert_difference -> { FieldCultivation.where(cultivation_plan_id: @plan.id).count }, +0 do
      # 全体としては keep(1) + new(1) - delete(1) = 0件差
      @saver.save_adjusted_result(@plan, result)
    end

    # 更新されたか
    @fc_keep.reload
    assert_equal 20.0, @fc_keep.area
    assert_equal 1500.0, @fc_keep.estimated_cost
    assert_equal Date.current + 2, @fc_keep.start_date
    assert_equal Date.current + 12, @fc_keep.completion_date

    # 新規が作成されたか（crop2 / field1）
    created = FieldCultivation.where(cultivation_plan_id: @plan.id)
                              .where(cultivation_plan_crop_id: @plan_crop2.id)
                              .where(cultivation_plan_field_id: @field1.id)
                              .order(id: :desc).first
    refute_nil created
    assert_equal 7.5, created.area

    # 削除対象は消え、TaskSchedule は null 化されたか
    refute FieldCultivation.exists?(id: @fc_delete.id)
    @ts_for_delete.reload
    assert_nil @ts_for_delete.field_cultivation_id

    # サマリ更新
    @plan.reload
    assert_equal 'completed', @plan.status
    assert_in_delta 123.0, @plan.total_profit.to_f, 0.001
    assert_in_delta 456.0, @plan.total_revenue.to_f, 0.001
    assert_in_delta 333.0, @plan.total_cost.to_f, 0.001
  end
end


