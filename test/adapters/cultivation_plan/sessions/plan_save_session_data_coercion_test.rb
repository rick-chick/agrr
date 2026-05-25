# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Sessions::PlanSaveSessionDataCoercionTest < ActiveSupport::TestCase
  test "deep_plain_hash converts nested ActionController::Parameters to plain hashes" do
    raw = ActionController::Parameters.new(
      plan_id: "42",
      farm_id: "7",
      crop_ids: [ "1", "2" ],
      field_data: [
        ActionController::Parameters.new(name: "A", area: "10", coordinates: [ "35", "139" ])
      ]
    )

    h = Adapters::CultivationPlan::Sessions::PlanSaveSessionDataCoercion.deep_plain_hash(raw)
    assert_kind_of Hash, h
    assert_equal "42", h["plan_id"]
    assert_equal 1, h["field_data"].size
    row = h["field_data"].first
    assert_kind_of Hash, row
    assert_equal "A", row["name"]
    assert_equal [ "35", "139" ], row["coordinates"]
  end

  test "session_payload_to_hash converts Parameters to plain hash" do
    params = ActionController::Parameters.new(
      plan_id: 99,
      farm_id: 5,
      crop_ids: [],
      field_data: []
    )

    h = Adapters::CultivationPlan::Sessions::PlanSaveSessionDataCoercion.session_payload_to_hash(params)

    assert_kind_of Hash, h
    assert_equal 99, h["plan_id"]
    assert_equal 5, h["farm_id"]
    assert_equal [], h["crop_ids"]
    assert_equal [], h["field_data"]
  end
end
