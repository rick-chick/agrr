# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersInteractionRulesContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
  end

  test "should get index" do
    create(
      :interaction_rule,
      :user_owned,
      user: @user,
      rule_type: "continuous_cultivation",
      source_group: "G1",
      target_group: "G2"
    )

    if rust_contract?
      response = rust_get("/api/v1/masters/interaction_rules", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/interaction_rules", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert json.is_a?(Array)
    assert json.length.positive?
  end

  test "should show interaction_rule" do
    rule = create(
      :interaction_rule,
      :user_owned,
      user: @user,
      rule_type: "continuous_cultivation",
      source_group: "SA",
      target_group: "TA"
    )

    if rust_contract?
      response = rust_get("/api/v1/masters/interaction_rules/#{rule.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/interaction_rules/#{rule.id}", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal rule.id, json["id"]
  end

  test "should create interaction_rule" do
    if rust_contract?
      response = rust_post(
        "/api/v1/masters/interaction_rules",
        session_id: @session_id,
        body: {
          interaction_rule: {
            rule_type: "continuous_cultivation",
            source_group: "A",
            target_group: "B",
            impact_ratio: 0.8
          }
        }
      )
      assert_equal 201, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      post "/api/v1/masters/interaction_rules",
           params: {
             interaction_rule: {
               rule_type: "continuous_cultivation",
               source_group: "A",
               target_group: "B",
               impact_ratio: 0.8
             }
           },
           headers: { "Accept" => "application/json" }
      assert_response :created
      json = JSON.parse(response.body)
    end

    assert json["id"].present?
  end

  test "should update interaction_rule" do
    rule = create(
      :interaction_rule,
      :user_owned,
      user: @user,
      rule_type: "continuous_cultivation",
      source_group: "X",
      target_group: "Y"
    )

    if rust_contract?
      response = rust_patch(
        "/api/v1/masters/interaction_rules/#{rule.id}",
        session_id: @session_id,
        body: { interaction_rule: { impact_ratio: 0.5 } }
      )
      assert_equal 200, response.code.to_i, response.body
    else
      sign_in_as @user
      patch "/api/v1/masters/interaction_rules/#{rule.id}",
            params: { interaction_rule: { impact_ratio: 0.5 } },
            headers: { "Accept" => "application/json" }
      assert_response :success
    end
  end

end
