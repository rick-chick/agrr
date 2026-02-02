# frozen_string_literal: true

require "test_helper"

module Crops
  class CropStagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      @session = Session.create_for_user(@user)
      cookies[:session_id] = @session.session_id
      @crop = create(:crop, user: @user)
    end

    test "create should return created with valid params" do
      valid_params = {
        crop_stage: {
          name: "発芽期",
          order: 1
        }
      }

      assert_difference "CropStage.count" do
        post crop_crop_stages_path(@crop), params: valid_params, as: :json
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
        post crop_crop_stages_path(@crop), params: invalid_params, as: :json
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
        post crop_crop_stages_path(@crop), params: invalid_params, as: :json
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
        post crop_crop_stages_path(99999), params: valid_params, as: :json
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

      post crop_crop_stages_path(@crop), params: valid_params, as: :json
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
        post crop_crop_stages_path(other_crop), params: valid_params, as: :json
      end

      assert_response :not_found
    end
  end
end