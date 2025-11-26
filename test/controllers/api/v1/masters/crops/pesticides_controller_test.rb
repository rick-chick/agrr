# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        class PesticidesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @user = create(:user)
            @user.generate_api_key!
            @api_key = @user.api_key
            @crop = create(:crop, :user_owned, user: @user)
            @pest = create(:pest, :user_owned, user: @user)
          end

          test "should get index" do
            pesticide1 = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
            pesticide2 = create(:pesticide, :reference, crop: @crop, pest: @pest)
            # 他の作物の農薬は含まれない
            other_crop = create(:crop, :user_owned, user: @user)
            other_pesticide = create(:pesticide, :user_owned, user: @user, crop: other_crop, pest: @pest)

            get api_v1_masters_crop_pesticides_path(@crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :success
            json_response = JSON.parse(response.body)
            assert_equal 2, json_response.length
            pesticide_ids = json_response.map { |p| p["id"] }
            assert_includes pesticide_ids, pesticide1.id
            assert_includes pesticide_ids, pesticide2.id
            assert_not_includes pesticide_ids, other_pesticide.id
          end

          test "should not get index for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)

            get api_v1_masters_crop_pesticides_path(other_crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Crop not found", json_response["error"]
          end

          test "should not include other user's pesticides" do
            other_user = create(:user)
            other_pesticide = create(:pesticide, :user_owned, user: other_user, crop: @crop, pest: @pest)

            get api_v1_masters_crop_pesticides_path(@crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :success
            json_response = JSON.parse(response.body)
            pesticide_ids = json_response.map { |p| p["id"] }
            assert_not_includes pesticide_ids, other_pesticide.id
          end
        end
      end
    end
  end
end
