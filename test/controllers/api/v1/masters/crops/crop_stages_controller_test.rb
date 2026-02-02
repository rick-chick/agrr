# frozen_string_literal: true

require "test_helper"

module Api::V1::Masters::Crops
  class CropStagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      @session = Session.create_for_user(@user)
      cookies[:session_id] = @session.session_id
      @crop = create(:crop, user: @user)
      @crop_stage = create(:crop_stage, crop: @crop)
    end

    test "create should return created with valid params" do
      valid_params = {
        crop_stage: {
          name: "発芽期",
          order: 1
        }
      }

      assert_difference "CropStage.count" do
        post api_v1_masters_crop_crop_stages_path(@crop), params: valid_params, as: :json
      end

      assert_response :created
      json = response.parsed_body
      assert_equal "発芽期", json["name"]
      assert_equal @crop.id, json["crop_id"]
      assert_equal 1, json["order"]
      assert json["id"].present?
    end

    test "create should return bad_request with invalid params" do
      invalid_params = {
        crop_stage: {
          name: "",  # 空文字は無効
          order: 1
        }
      }

      assert_no_difference "CropStage.count" do
        post api_v1_masters_crop_crop_stages_path(@crop), params: invalid_params, as: :json
      end

      assert_response :bad_request
      json = response.parsed_body
      assert json["error"].present?
    end

    test "create should return bad_request without required params" do
      invalid_params = {
        crop_stage: {}  # パラメータなし
      }

      assert_no_difference "CropStage.count" do
        post api_v1_masters_crop_crop_stages_path(@crop), params: invalid_params, as: :json
      end

      assert_response :bad_request
      json = response.parsed_body
      assert json["error"].present?
    end

    test "create should return not_found for non-existent crop" do
      valid_params = {
        crop_stage: {
          name: "発芽期",
          order: 1
        }
      }

      assert_no_difference "CropStage.count" do
        post api_v1_masters_crop_crop_stages_path(99999), params: valid_params, as: :json
      end

      assert_response :not_found
      json = response.parsed_body
      assert_equal "Crop not found", json["error"]
    end

    test "should return unauthorized when not logged in" do
      # Clear session by setting invalid session_id
      cookies[:session_id] = 'invalid_session'

      valid_params = {
        crop_stage: {
          name: "発芽期",
          order: 1
        }
      }

      post api_v1_masters_crop_crop_stages_path(@crop), params: valid_params, as: :json
      assert_response :unauthorized
    end

    test "should return forbidden for other user's crop" do
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)

      valid_params = {
        crop_stage: {
          name: "発芽期",
          order: 1
        }
      }

      assert_no_difference "CropStage.count" do
        post api_v1_masters_crop_crop_stages_path(other_crop), params: valid_params, as: :json
      end

      assert_response :not_found
    end

    test "index should return crop stages for valid crop" do
      create(:crop_stage, crop: @crop, name: "種まき", order: 2)
      create(:crop_stage, crop: @crop, name: "発芽", order: 3)

      get api_v1_masters_crop_crop_stages_path(@crop)
      assert_response :success

      json = response.parsed_body
      assert_equal 3, json.length  # setupで1つ、テストで2つ作成
      assert_equal ["種まき", "発芽", @crop_stage.name].sort, json.pluck("name").sort
    end

    test "index should return not_found for non-existent crop" do
      get api_v1_masters_crop_crop_stages_path(99999)
      assert_response :not_found
      json = response.parsed_body
      assert_equal "Crop not found", json["error"]
    end

    test "index should return forbidden for other user's crop" do
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)

      get api_v1_masters_crop_crop_stages_path(other_crop)
      assert_response :not_found
    end

    test "show should return crop stage with valid id" do
      get api_v1_masters_crop_crop_stage_path(@crop, @crop_stage)
      assert_response :success

      json = response.parsed_body
      assert_equal @crop_stage.id, json["id"]
      assert_equal @crop_stage.name, json["name"]
      assert_equal @crop.id, json["crop_id"]
      assert_equal @crop_stage.order, json["order"]
    end

    test "show should return not_found with invalid crop_stage id" do
      get api_v1_masters_crop_crop_stage_path(@crop, 99999)
      assert_response :not_found
      json = response.parsed_body
      assert_equal "CropStage not found", json["error"]
    end

    test "show should return not_found for other user's crop" do
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)
      other_crop_stage = create(:crop_stage, crop: other_crop)

      get api_v1_masters_crop_crop_stage_path(other_crop, other_crop_stage)
      assert_response :not_found
    end

    test "update should modify crop stage with valid params" do
      update_params = {
        crop_stage: {
          name: "新しい名前",
          order: 5
        }
      }

      patch api_v1_masters_crop_crop_stage_path(@crop, @crop_stage), params: update_params, as: :json
      assert_response :success

      @crop_stage.reload
      assert_equal "新しい名前", @crop_stage.name
      assert_equal 5, @crop_stage.order

      json = response.parsed_body
      assert_equal "新しい名前", json["name"]
      assert_equal 5, json["order"]
    end

  test "admin can create crop stage for reference crop" do
    admin = create(:user, :admin)
    session = Session.create_for_user(admin)
    cookies[:session_id] = session.session_id
    reference_crop = create(:crop, :reference)

    valid_params = {
      crop_stage: {
        name: "参照作物の生育",
        order: 2
      }
    }

    assert_difference "CropStage.count" do
      post api_v1_masters_crop_crop_stages_path(reference_crop), params: valid_params, as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert_equal reference_crop.id, json["crop_id"]
    assert_equal "参照作物の生育", json["name"]
    assert_equal 2, json["order"]
  end

  test "admin can update crop stage for reference crop" do
    admin = create(:user, :admin)
    session = Session.create_for_user(admin)
    cookies[:session_id] = session.session_id
    reference_crop = create(:crop, :reference)
    reference_stage = create(:crop_stage, crop: reference_crop, name: "前", order: 1)

    update_params = {
      crop_stage: {
        name: "更新後",
        order: 3
      }
    }

    patch api_v1_masters_crop_crop_stage_path(reference_crop, reference_stage), params: update_params, as: :json
    assert_response :success

    reference_stage.reload
    assert_equal "更新後", reference_stage.name
    assert_equal 3, reference_stage.order
  end

    test "update should return bad_request with invalid params" do
      invalid_params = {
        crop_stage: {
          name: "",  # 空文字は無効
          order: 1
        }
      }

      patch api_v1_masters_crop_crop_stage_path(@crop, @crop_stage), params: invalid_params, as: :json
      assert_response :bad_request
      json = response.parsed_body
      assert json["error"].present?
    end

    test "update should return bad_request without required params" do
      invalid_params = {
        crop_stage: {}  # パラメータなし
      }

      patch api_v1_masters_crop_crop_stage_path(@crop, @crop_stage), params: invalid_params, as: :json
      assert_response :bad_request
      json = response.parsed_body
      assert json["error"].present?
    end

    test "update should return not_found with invalid crop_stage id" do
      update_params = {
        crop_stage: {
          name: "新しい名前",
          order: 5
        }
      }

      patch api_v1_masters_crop_crop_stage_path(@crop, 99999), params: update_params, as: :json
      assert_response :not_found
      json = response.parsed_body
      assert_equal "CropStage not found", json["error"]
    end

    test "destroy should delete crop stage" do
      assert_difference "CropStage.count", -1 do
        delete api_v1_masters_crop_crop_stage_path(@crop, @crop_stage)
      end

      assert_response :success
      json = response.parsed_body
      assert_equal true, json["success"]
    end

    test "destroy should return not_found with invalid crop_stage id" do
      assert_no_difference "CropStage.count" do
        delete api_v1_masters_crop_crop_stage_path(@crop, 99999)
      end

      assert_response :not_found
      json = response.parsed_body
      assert_equal "CropStage not found", json["error"]
    end
  end
end