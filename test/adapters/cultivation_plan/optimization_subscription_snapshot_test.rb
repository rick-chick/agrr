# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    class OptimizationSubscriptionSnapshotTest < ActiveSupport::TestCase
      test "payload_for completed plan" do
        plan = create(:cultivation_plan, :public_plan, status: "completed")

        payload = OptimizationSubscriptionSnapshot.payload_for(plan)

        assert_equal "completed", payload[:status]
        assert_equal 100, payload[:progress]
      end

      test "payload_for optimizing plan includes phase message key" do
        plan = create(:cultivation_plan, :public_plan, status: "optimizing", optimization_phase: "fetching_weather")
        plan.update!(optimization_phase_message: "気象データを取得しています...")

        payload = OptimizationSubscriptionSnapshot.payload_for(plan)

        assert_equal "optimizing", payload[:status]
        assert_equal "fetching_weather", payload[:phase]
        assert_equal "models.cultivation_plan.phases.fetching_weather", payload[:message_key]
      end

      test "payload_for pending plan is nil" do
        plan = create(:cultivation_plan, :public_plan, status: "pending")

        assert_nil OptimizationSubscriptionSnapshot.payload_for(plan)
      end
    end
  end
end
