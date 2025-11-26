# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
          setup do
            @user = create(:user)
            @user.generate_api_key!
            @api_key = @user.api_key
            @crop = create(:crop, :user_owned, user: @user)
          end

          test "should get index" do
            task1 = create(:agricultural_task, :user_owned, user: @user)
            task2 = create(:agricultural_task, :reference)
            template1 = create(:crop_task_template, crop: @crop, agricultural_task: task1, name: "タスク1")
            template2 = create(:crop_task_template, crop: @crop, agricultural_task: task2, name: "タスク2")

            get api_v1_masters_crop_agricultural_tasks_path(@crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :success
            json_response = JSON.parse(response.body)
            assert_equal 2, json_response.length
            template_ids = json_response.map { |t| t["id"] }
            assert_includes template_ids, template1.id
            assert_includes template_ids, template2.id
          end

          test "should not get index for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)

            get api_v1_masters_crop_agricultural_tasks_path(other_crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Crop not found", json_response["error"]
          end

          test "should create association" do
            task = create(:agricultural_task, :user_owned, user: @user, name: "元のタスク名")

            assert_difference("@crop.crop_task_templates.count", 1) do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {
                     agricultural_task_id: task.id,
                     name: "カスタムタスク名",
                     time_per_sqm: 0.5,
                     description: "カスタム説明"
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert_equal task.id, json_response["agricultural_task_id"]
            assert_equal "カスタムタスク名", json_response["name"]
            assert_equal 0.5, json_response["time_per_sqm"]
            assert_equal "カスタム説明", json_response["description"]
          end

          test "should create association with default values" do
            task = create(:agricultural_task, :user_owned, user: @user, 
                         name: "デフォルトタスク名",
                         description: "デフォルト説明",
                         time_per_sqm: 1.0)

            assert_difference("@crop.crop_task_templates.count", 1) do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {
                     agricultural_task_id: task.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert_equal task.id, json_response["agricultural_task_id"]
            assert_equal "デフォルトタスク名", json_response["name"]
            assert_equal 1.0, json_response["time_per_sqm"]
            assert_equal "デフォルト説明", json_response["description"]
          end

          test "should not create association without agricultural_task_id" do
            assert_no_difference("@crop.crop_task_templates.count") do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {},
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :unprocessable_entity
            json_response = JSON.parse(response.body)
            assert_equal "agricultural_task_id is required", json_response["error"]
          end

          test "should not create association with non-existent task" do
            assert_no_difference("@crop.crop_task_templates.count") do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {
                     agricultural_task_id: 99999
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "AgriculturalTask not found", json_response["error"]
          end

          test "should not create association with other user's task" do
            other_user = create(:user)
            other_task = create(:agricultural_task, :user_owned, user: other_user)

            assert_no_difference("@crop.crop_task_templates.count") do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {
                     agricultural_task_id: other_task.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :forbidden
            json_response = JSON.parse(response.body)
            assert_equal "You do not have permission to associate this agricultural task", json_response["error"]
          end

          test "should not create duplicate association" do
            task = create(:agricultural_task, :user_owned, user: @user)
            create(:crop_task_template, crop: @crop, agricultural_task: task)

            assert_no_difference("@crop.crop_task_templates.count") do
              post api_v1_masters_crop_agricultural_tasks_path(@crop),
                   params: {
                     agricultural_task_id: task.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :unprocessable_entity
            json_response = JSON.parse(response.body)
            assert_equal "AgriculturalTask is already associated with this crop", json_response["error"]
          end

          test "should update template" do
            task = create(:agricultural_task, :user_owned, user: @user)
            template = create(:crop_task_template, crop: @crop, agricultural_task: task, name: "元の名前", time_per_sqm: 0.5)

            patch api_v1_masters_crop_agricultural_task_path(@crop, template),
                  params: {
                    name: "更新された名前",
                    time_per_sqm: 0.8
                  },
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

            assert_response :success
            json_response = JSON.parse(response.body)
            assert_equal "更新された名前", json_response["name"]
            assert_equal 0.8, json_response["time_per_sqm"]

            template.reload
            assert_equal "更新された名前", template.name
            assert_equal 0.8, template.time_per_sqm
          end

          test "should not update template for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            task = create(:agricultural_task, :user_owned, user: other_user)
            template = create(:crop_task_template, crop: other_crop, agricultural_task: task)

            patch api_v1_masters_crop_agricultural_task_path(other_crop, template),
                  params: {
                    name: "変更しようとした名前"
                  },
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

            assert_response :not_found
          end

          test "should destroy association" do
            task = create(:agricultural_task, :user_owned, user: @user)
            template = create(:crop_task_template, crop: @crop, agricultural_task: task)

            assert_difference("@crop.crop_task_templates.count", -1) do
              delete api_v1_masters_crop_agricultural_task_path(@crop, template),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :no_content
          end

          test "should not destroy association for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            task = create(:agricultural_task, :user_owned, user: other_user)
            template = create(:crop_task_template, crop: other_crop, agricultural_task: task)

            assert_no_difference("CropTaskTemplate.count") do
              delete api_v1_masters_crop_agricultural_task_path(other_crop, template),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :not_found
          end
        end
      end
    end
  end
end
