require "test_helper"

module Api
  module V1
    class PlansControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create(:user)
        @farm = create(:farm, user: @user)
        @crop = create(:crop, :user_owned, user: @user)
        sign_in_as @user
      end

      test "create creates a new private plan successfully" do
        assert_difference "::CultivationPlan.count", +1 do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: @farm.id,
                   plan_name: "テスト計画",
                   crop_ids: [@crop.id]
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :created
        json = JSON.parse(response.body)
        assert json["id"].present?

        plan = ::CultivationPlan.find(json["id"])
        assert_equal @user.id, plan.user_id
        assert_equal @farm.id, plan.farm_id
        assert_equal "テスト計画", plan.plan_name
        assert_equal "private", plan.plan_type
      end

      test "create uses farm name when plan_name is not provided" do
        assert_difference "::CultivationPlan.count", +1 do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: @farm.id,
                   crop_ids: [@crop.id]
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :created
        json = JSON.parse(response.body)

        plan = ::CultivationPlan.find(json["id"])
        assert_equal @farm.name, plan.plan_name
      end

      test "create fails when no crops selected" do
        assert_no_difference -> { ::CultivationPlan.count } do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: @farm.id,
                   crop_ids: []
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      test "create fails when plan already exists for the same farm and user" do
        create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)

        assert_no_difference -> { ::CultivationPlan.count } do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: @farm.id,
                   crop_ids: [@crop.id]
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      test "create fails when farm not found" do
        assert_no_difference -> { ::CultivationPlan.count } do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: 99999,
                   crop_ids: [@crop.id]
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :not_found
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      test "create fails when not authenticated" do
        # Clear session to make user anonymous
        cookies.delete('session_id')

        assert_no_difference -> { ::CultivationPlan.count } do
          post api_v1_plans_path,
               params: {
                 plan: {
                   farm_id: @farm.id,
                   crop_ids: [@crop.id]
                 }
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :unauthorized
      end

      test "index returns user's private plans" do
        farm2 = create(:farm, user: @user)
        plan1 = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
        plan2 = create(:cultivation_plan, :annual_planning, farm: farm2, user: @user, plan_type: :private)

        get api_v1_plans_path, headers: { "Accept" => "application/json" }

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal 2, json.length

        plan_ids = json.map { |p| p["id"] }
        assert_includes plan_ids, plan1.id
        assert_includes plan_ids, plan2.id
      end

      test "show returns specific plan" do
        farm3 = create(:farm, user: @user)
        plan = create(:cultivation_plan, :annual_planning, farm: farm3, user: @user, plan_type: :private)

        get "/api/v1/plans/#{plan.id}", headers: { "Accept" => "application/json" }

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal plan.id, json["id"]
        assert_equal plan.display_name, json["name"]
        assert_equal plan.status, json["status"]
      end
    end
  end
end