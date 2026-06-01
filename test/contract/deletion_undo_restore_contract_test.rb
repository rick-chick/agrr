# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: POST /undo_deletion after masters API destroy (agrr-server)
class DeletionUndoRestoreContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @rule = create(:interaction_rule, :user_owned, user: @user)
  end

  test "restore_after_masters_api_destroy_of_interaction_rule" do
    delete_resp = rust_delete(
      "/api/v1/masters/interaction_rules/#{@rule.id}",
      session_id: @session_id
    )
    assert_equal 200, delete_resp.code.to_i, delete_resp.body
    undo_body = JSON.parse(delete_resp.body)
    undo_token = undo_body["undo_token"] || undo_body.dig("undo", "undo_token")
    assert undo_token.present?
    assert undo_body["undo_path"].present?, undo_body.inspect
    assert_equal "/undo_deletion?undo_token=#{undo_token}", undo_body["undo_path"]
    assert_not InteractionRule.exists?(@rule.id)

    restore_resp = rust_post(
      "/undo_deletion",
      body: { undo_token: undo_token }
    )
    assert_equal 200, restore_resp.code.to_i, restore_resp.body
    json = JSON.parse(restore_resp.body)

    assert_equal "restored", json.fetch("status")
    assert_equal undo_token, json.fetch("undo_token")
    event = DeletionUndoEvent.find(undo_token)
    assert_equal "restored", event.state
    row_count = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM interaction_rules WHERE id = #{@rule.id.to_i}"
    )
    assert_equal 1, row_count.to_i, "interaction_rules row missing after undo restore"
  end

  test "restore_after_masters_api_destroy_of_farm" do
    farm = create(:farm, :user_owned, user: @user)

    delete_resp = rust_delete(
      "/api/v1/masters/farms/#{farm.id}",
      session_id: @session_id
    )
    assert_equal 200, delete_resp.code.to_i, delete_resp.body
    undo_body = JSON.parse(delete_resp.body)
    undo_token = undo_body["undo_token"] || undo_body.dig("undo", "undo_token")
    assert undo_token.present?, undo_body.inspect
    undo_path = undo_body["undo_path"] || undo_body.dig("undo", "undo_path")
    assert_equal "/undo_deletion?undo_token=#{undo_token}", undo_path
    assert_not Farm.exists?(farm.id)

    restore_resp = rust_post(
      "/undo_deletion",
      body: { undo_token: undo_token }
    )
    assert_equal 200, restore_resp.code.to_i, restore_resp.body
    json = JSON.parse(restore_resp.body)

    assert_equal "restored", json.fetch("status")
    assert_equal undo_token, json.fetch("undo_token")
    event = DeletionUndoEvent.find(undo_token)
    assert_equal "restored", event.state
    row_count = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM farms WHERE id = #{farm.id.to_i}"
    )
    assert_equal 1, row_count.to_i, "farms row missing after undo restore"
  end
end
