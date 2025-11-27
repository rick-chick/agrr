# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "includes ApiCrudResponder" do
          assert_includes Api::V1::Masters::AgriculturalTasksController.included_modules, ApiCrudResponder
        end

        test "should get index" do
          task1 = create(:agricultural_task, :user_owned, user: @user)
          task2 = create(:agricultural_task, :user_owned, user: @user)
          # 参照タスクは含まれない
          reference_task = create(:agricultural_task, :reference)
          # 他のユーザーのタスクは含まれない
          other_user = create(:user)
          other_task = create(:agricultural_task, :user_owned, user: other_user)

          get api_v1_masters_agricultural_tasks_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          task_ids = json_response.map { |t| t["id"] }
          assert_includes task_ids, task1.id
          assert_includes task_ids, task2.id
          assert_not_includes task_ids, reference_task.id
          assert_not_includes task_ids, other_task.id
        end

        test "should show agricultural_task" do
          task = create(:agricultural_task, :user_owned, user: @user, name: "テストタスク")

          get api_v1_masters_agricultural_task_path(task),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal task.id, json_response["id"]
          assert_equal "テストタスク", json_response["name"]
        end

        test "should not show other user's agricultural_task" do
          other_user = create(:user)
          other_task = create(:agricultural_task, :user_owned, user: other_user)

          get api_v1_masters_agricultural_task_path(other_task),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :forbidden
          json_response = JSON.parse(response.body)
          assert_equal I18n.t("agricultural_tasks.flash.no_permission"), json_response["error"]
        end

        test "should create agricultural_task" do
          assert_difference("@user.agricultural_tasks.where(is_reference: false).count", 1) do
            post api_v1_masters_agricultural_tasks_path,
                 params: {
                   agricultural_task: {
                     name: "新規タスク",
                     description: "テスト説明",
                     time_per_sqm: 0.5
                   }
                 },
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規タスク", json_response["name"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update agricultural_task" do
          task = create(:agricultural_task, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_agricultural_task_path(task),
                params: {
                  agricultural_task: {
                    name: "更新された名前"
                  }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal "更新された名前", json_response["name"]
        end

        test "should not update other user's agricultural_task" do
          other_user = create(:user)
          other_task = create(:agricultural_task, :user_owned, user: other_user, name: "他のユーザーのタスク")

          patch api_v1_masters_agricultural_task_path(other_task),
                params: {
                  agricultural_task: {
                    name: "変更しようとした名前"
                  }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :forbidden

          other_task.reload
          assert_equal "他のユーザーのタスク", other_task.name
        end

        test "should destroy agricultural_task" do
          task = create(:agricultural_task, :user_owned, user: @user)

          assert_difference("@user.agricultural_tasks.where(is_reference: false).count", -1) do
            delete api_v1_masters_agricultural_task_path(task),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :no_content
        end

        test "should not destroy other user's agricultural_task" do
          other_user = create(:user)
          other_task = create(:agricultural_task, :user_owned, user: other_user)

          assert_no_difference("AgriculturalTask.count") do
            delete api_v1_masters_agricultural_task_path(other_task),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :forbidden
        end
      end
    end
  end
end
