require "test_helper"

DeletionUndo::Manager # ensure DeletionUndo constants are loaded before controller/interactor run

module Api
  module V1
    class PlansControllerTest < ActionDispatch::IntegrationTest
      include ActionView::RecordIdentifier
      setup do
        @user = create(:user)
        @farm = create(:farm, :with_field, user: @user)
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

      test "destroy deletes plan successfully and returns undo token" do
        plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)

        assert_difference "DeletionUndoEvent.count", +1 do
          assert_difference "::CultivationPlan.count", -1 do
            delete "/api/v1/plans/#{plan.id}", headers: { "Accept" => "application/json" }
          end
        end

        assert_response :success
        json = JSON.parse(response.body)
        # Contract: DeletionUndoResponse fields
        assert json["undo_token"].present?, "undo_token should be present"
        event = DeletionUndoEvent.find_by!(id: json["undo_token"])
        assert_equal I18n.t('plans.undo.toast', name: plan.display_name), json["toast_message"]
        assert_equal dom_id(plan), json["resource_dom_id"]
        assert_equal plan.display_name, json["resource"]
        assert_equal "/plans", json["redirect_path"]
        assert_equal undo_deletion_path(undo_token: json["undo_token"]), json["undo_path"]
        assert_equal event.auto_hide_after, json["auto_hide_after"]
        assert_equal event.metadata['undo_deadline'], json["undo_deadline"]
        assert json["undo_deadline"].present?
        assert json["auto_hide_after"].present?
      end

      test "destroy returns 404 when plan not found" do
        delete "/api/v1/plans/99999", headers: { "Accept" => "application/json" }

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal I18n.t('plans.errors.not_found'), json["error"]
      end

      test "destroy returns 404 when plan belongs to another user" do
        other_user = create(:user)
        other_farm = create(:farm, user: other_user)
        other_plan = create(:cultivation_plan, :annual_planning, farm: other_farm, user: other_user, plan_type: :private)

        assert_no_difference "::CultivationPlan.count" do
          delete "/api/v1/plans/#{other_plan.id}", headers: { "Accept" => "application/json" }
        end

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal I18n.t('plans.errors.not_found'), json["error"]
      end

      test "destroy returns 422 when deletion fails" do
        plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
        
        # Mock DeletionUndo::Manager to raise an error that results in 422
        DeletionUndo::Manager.stub(:schedule, ->(*) { raise ActiveRecord::DeleteRestrictionError }) do
          assert_no_difference "::CultivationPlan.count" do
            delete "/api/v1/plans/#{plan.id}", headers: { "Accept" => "application/json" }
          end
        end

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert_equal I18n.t('plans.errors.delete_failed'), json["error"]
      end

      test "destroy returns unauthorized when not authenticated" do
        plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
        cookies.delete("session_id")

        delete "/api/v1/plans/#{plan.id}", headers: { "Accept" => "application/json" }

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal I18n.t("auth.api.login_required"), json["error"]
      end
    end
  end
end