# frozen_string_literal: true

require "test_helper"

# POST /undo_deletion（JSON）の復元契約。undo 生成は各 masters API destroy（または HTML destroy）側。
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

  test "restore_after_masters_api_destroy_of_pest" do
    pest = create(:pest, :user_owned, user: @user)

    assert_difference -> { Pest.count }, -1 do
      delete api_v1_masters_pest_path(pest), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not Pest.exists?(pest.id), "削除後に Pest が残っています"

    assert_difference -> { Pest.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert Pest.exists?(pest.id), "Undo 後に Pest が復元されていません"
  end

  test "restore_after_masters_api_destroy_of_pesticide" do
    crop = create(:crop, :user_owned, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    pesticide = create(:pesticide, :user_owned, user: @user, crop: crop, pest: pest)

    assert_difference -> { Pesticide.count }, -1 do
      delete api_v1_masters_pesticide_path(pesticide), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not Pesticide.exists?(pesticide.id)

    assert_difference -> { Pesticide.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert Pesticide.exists?(pesticide.id)
  end

  test "restore_after_masters_api_destroy_of_agricultural_task" do
    task = create(:agricultural_task, :user_owned, user: @user)

    assert_difference -> { AgriculturalTask.count }, -1 do
      delete api_v1_masters_agricultural_task_path(task), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not AgriculturalTask.exists?(task.id)

    assert_difference -> { AgriculturalTask.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert AgriculturalTask.exists?(task.id)
  end

  test "restore_after_masters_api_destroy_of_crop" do
    crop = create(:crop, :user_owned, user: @user)

    assert_difference -> { Crop.count }, -1 do
      delete api_v1_masters_crop_path(crop), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo").fetch("undo_token")
    assert_not Crop.exists?(crop.id)

    assert_difference -> { Crop.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert Crop.exists?(crop.id)
  end

  test "restore_after_masters_api_destroy_of_field" do
    farm = create(:farm, :user_owned, user: @user)
    field = create(:field, farm: farm, user: @user)

    assert_difference -> { Field.count }, -1 do
      delete api_v1_masters_field_path(field), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo_token")
    assert_not Field.exists?(field.id)

    assert_difference -> { Field.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert Field.exists?(field.id)
  end

  test "restore_after_masters_api_destroy_of_farm" do
    farm = create(:farm, :user_owned, user: @user)

    assert_difference -> { Farm.count }, -1 do
      delete api_v1_masters_farm_path(farm), headers: @api_headers
      assert_response :success
    end

    undo_token = @response.parsed_body.fetch("undo").fetch("undo_token")
    assert_not Farm.exists?(farm.id)

    assert_difference -> { Farm.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    assert_equal "restored", @response.parsed_body.fetch("status")
    assert Farm.exists?(farm.id)
  end
end
