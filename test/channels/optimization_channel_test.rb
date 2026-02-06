require 'test_helper'
require 'securerandom'

class OptimizationChannelTest < ActionCable::Channel::TestCase
  test 'subscribes to public plan without session_id' do
    plan = create(:cultivation_plan, :public_plan, session_id: nil)
    stub_connection(session_id: '', current_user: nil)
    subscribe cultivation_plan_id: plan.id
    assert subscription.confirmed?
    assert_has_stream_for plan
  end

  test 'subscribes to public plan even with mismatched session_id' do
    plan = create(:cultivation_plan, :public_plan, session_id: 'session-match')
    stub_connection(session_id: 'session-mismatch', current_user: nil)
    subscribe cultivation_plan_id: plan.id
    assert subscription.confirmed?
    assert_has_stream_for plan
  end

  test 'subscribes when session_id matches public plan' do
    plan = create(:cultivation_plan, :public_plan, session_id: SecureRandom.urlsafe_base64(32))
    stub_connection(session_id: plan.session_id, current_user: nil)
    subscribe cultivation_plan_id: plan.id
    assert subscription.confirmed?
    assert_has_stream_for plan
  end

  test 'rejects subscription when plan not found' do
    stub_connection(session_id: 'any', current_user: nil)
    subscribe cultivation_plan_id: 99999
    assert subscription.rejected?
  end
end
