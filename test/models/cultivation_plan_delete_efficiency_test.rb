require "test_helper"

class CultivationPlanDeleteEfficiencyTest < ActiveSupport::TestCase
  def setup
    @plan = create(:cultivation_plan)
    field = create(:cultivation_plan_field, cultivation_plan: @plan)
    crop = create(:crop, :with_stages)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    fc1 = create(:field_cultivation, cultivation_plan: @plan, cultivation_plan_field: field, cultivation_plan_crop: plan_crop)
    fc2 = create(:field_cultivation, cultivation_plan: @plan, cultivation_plan_field: field, cultivation_plan_crop: plan_crop)

    # それぞれにスケジュールとアイテムを付与
    ts1 = create(:task_schedule, cultivation_plan: @plan, field_cultivation: fc1)
    ts2 = create(:task_schedule, cultivation_plan: @plan, field_cultivation: fc2)
    3.times { create(:task_schedule_item, task_schedule: ts1) }
    2.times { create(:task_schedule_item, task_schedule: ts2) }
  end

  test "delete_all removes schedules and items when plan is destroyed" do
    assert_difference -> { TaskSchedule.count }, -2 do
      assert_difference -> { TaskScheduleItem.count }, -5 do
        assert_difference -> { CultivationPlan.count }, -1 do
          @plan.destroy!
        end
      end
    end
  end
end


