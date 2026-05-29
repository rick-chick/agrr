# frozen_string_literal: true

require "test_helper"
require "securerandom"

# R4: mirrors observable behavior of test/channels/optimization_channel_test.rb
class OptimizationChannelContractTest < ActionCable::Channel::TestCase
  tests OptimizationChannel
  test "subscribes to public plan without session_id" do
    plan = create(:cultivation_plan, :public_plan, session_id: nil)
    stub_connection(session_id: "", current_user: nil)
    subscribe cultivation_plan_id: plan.id
    assert subscription.confirmed?
    assert_has_stream_for plan
  end

  test "rejects subscription when plan not found" do
    stub_connection(session_id: "any", current_user: nil)
    subscribe cultivation_plan_id: 99_999
    assert subscription.rejected?
  end
end
