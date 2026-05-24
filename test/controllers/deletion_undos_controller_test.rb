# frozen_string_literal: true

require "test_helper"

# POST /undo_deletion（JSON）の HTTP 契約。削除元リソース種別ごとの undo 生成は各 masters API / HTML controller 側。
class DeletionUndosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user.generate_api_key!
    @api_headers = {
      "Accept" => "application/json",
      "X-API-Key" => @user.api_key
    }
  end

  test "restore_after_masters_api_destroy_of_interaction_rule" do
    rule = create(:interaction_rule, :user_owned, user: @user)

    assert_difference -> { InteractionRule.count }, -1 do
      delete api_v1_masters_interaction_rule_path(rule), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not InteractionRule.exists?(rule.id), "削除後に InteractionRule が残っています"

    assert_difference -> { InteractionRule.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = @response.parsed_body
    assert_equal "restored", undo_body.fetch("status")
    assert_equal undo_token, undo_body.fetch("undo_token")

    event = DeletionUndoEvent.find(undo_token)
    assert_equal "restored", event.state
    assert InteractionRule.exists?(rule.id), "Undo 後に InteractionRule が復元されていません"
  end

  test "restore_after_masters_api_destroy_of_fertilize" do
    fertilize = create(:fertilize, :user_owned, user: @user)

    assert_difference -> { Fertilize.count }, -1 do
      delete api_v1_masters_fertilize_path(fertilize), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not Fertilize.exists?(fertilize.id), "削除後に Fertilize が残っています"

    assert_difference -> { Fertilize.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = @response.parsed_body
    assert_equal "restored", undo_body.fetch("status")
    assert_equal undo_token, undo_body.fetch("undo_token")

    event = DeletionUndoEvent.find(undo_token)
    assert_equal "restored", event.state
    assert Fertilize.exists?(fertilize.id), "Undo 後に Fertilize が復元されていません"
  end
end
