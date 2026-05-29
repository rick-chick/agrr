# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors phase broadcast payload keys from advance_cultivation_plan_phase interactor tests
class AdvanceCultivationPlanPhaseContractTest < ContractTestCase
  test "phase broadcast payload includes status progress phase message_key" do
    plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
      id: 1,
      farm_id: 1,
      user_id: 1,
      total_area: 100.0,
      plan_type: "public",
      status: "optimizing",
      optimization_phase: "fetching_weather",
      optimization_phase_message: "取得中"
    )
    payload = Domain::CultivationPlan::Mappers::CultivationPlanPhaseBroadcastPayloadMapper.to_port_payload(
      plan: plan,
      progress: 100,
      phase_message: "気象取得中"
    )
    assert_equal "optimizing", payload[:status]
    assert_equal 100, payload[:progress]
    assert_equal "fetching_weather", payload[:phase]
    assert payload[:message_key].to_s.include?("fetching_weather")
  end
end
