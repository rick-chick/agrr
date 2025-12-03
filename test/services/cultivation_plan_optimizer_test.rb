require 'test_helper'

class CultivationPlanOptimizerTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @farm = create(:farm, user: @user)
  end

  test 'calculate_planning_period uses next year end for public plan without field_cultivations' do
    plan = create(:cultivation_plan, :public_plan, farm: @farm, user: @user)
    plan.field_cultivations.destroy_all

    optimizer = CultivationPlanOptimizer.new(plan, 'OptimizationChannel')
    planning_start, planning_end = optimizer.send(:calculate_planning_period)

    assert_equal Date.current, planning_start
    assert_equal plan.prediction_target_end_date, planning_end
  end
end

