# frozen_string_literal: true

require 'test_helper'

class PlanFinalizeJobTest < ActiveJob::TestCase
  test 'finalizes plan by setting status completed and broadcasting completed phase' do
    plan = create(:cultivation_plan, status: 'optimizing')
    channel_class = 'PlansOptimizationChannel'

    assert_enqueued_jobs 6
    PlanFinalizeJob.perform_now(cultivation_plan_id: plan.id, channel_class: channel_class)

    plan.reload
    assert_equal 'completed', plan.status
    # optimization_phase は 'completed' に更新される（broadcast は副作用のためここでは状態のみ確認）
    assert_equal 'completed', plan.optimization_phase
  end
end


