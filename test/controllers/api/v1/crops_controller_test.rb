require "test_helper"

module Api
  module V1
    class CropsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create(:user)
        sign_in_as @user
      end

      test "ai_create creates a new user-owned non-reference crop when none exists" do
        agrr_response = {
          "success" => true,
          "crop" => {
            "crop_id" => nil,
            "name" => "ブロッコリー",
            "variety" => "スプラウト",
            "area_per_unit" => 10.5,
            "revenue_per_area" => 20000,
            "groups" => ["葉物"]
          },
          "stage_requirements" => []
        }

        Api::V1::CropsController.class_eval do
          define_method(:fetch_crop_info_from_agrr) do |crop_name, max_retries: 3|
            agrr_response
          end
        end

        assert_difference "Crop.count", +1 do
          post api_v1_crops_ai_create_path,
               params: { name: "ブロッコリー" },
               headers: { "Accept" => "application/json" }
        end

        assert_response :created
        json = JSON.parse(response.body)

        assert json["success"]
        crop = Crop.find(json["crop_id"])
        assert_equal @user.id, crop.user_id
        assert_not crop.is_reference
        assert_equal ["葉物"], crop.groups
      end

      test "ai_create updates existing editable crop instead of creating a new one" do
        existing = create(:crop, :user_owned, user: @user, name: "トマト", area_per_unit: 5.0, revenue_per_area: 10000, groups: [])

        agrr_response = {
          "success" => true,
          "crop" => {
            "crop_id" => existing.id,
            "name" => "トマト",
            "variety" => "改良種",
            "area_per_unit" => 8.0,
            "revenue_per_area" => 15000,
            "groups" => ["果菜"]
          },
          "stage_requirements" => []
        }

        Api::V1::CropsController.class_eval do
          define_method(:fetch_crop_info_from_agrr) do |crop_name, max_retries: 3|
            agrr_response
          end
        end

        assert_no_difference "Crop.count" do
          post api_v1_crops_ai_create_path,
               params: { name: "トマト" },
               headers: { "Accept" => "application/json" }
        end

        assert_response :ok
        json = JSON.parse(response.body)

        assert json["success"]
        existing.reload
        assert_equal existing.id, json["crop_id"]
        assert_equal 8.0, existing.area_per_unit
        assert_equal 15000, existing.revenue_per_area
        assert_equal ["果菜"], existing.groups
        assert_equal @user.id, existing.user_id
        assert_not existing.is_reference
      end
    end
  end
end

