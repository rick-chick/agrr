# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class FieldsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
          @farm = create(:farm, :user_owned, user: @user)
        end

        test "should get index" do
          field1 = create(:field, farm: @farm, user: @user)
          field2 = create(:field, farm: @farm, user: @user)
          # 他の農場の圃場は含まれない
          other_farm = create(:farm, :user_owned, user: @user)
          other_field = create(:field, farm: other_farm, user: @user)

          get api_v1_masters_farm_fields_path(@farm), 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          field_ids = json_response.map { |f| f["id"] }
          assert_includes field_ids, field1.id
          assert_includes field_ids, field2.id
          assert_not_includes field_ids, other_field.id
        end

        test "should show field" do
          field = create(:field, farm: @farm, user: @user, name: "テスト圃場")

          get api_v1_masters_field_path(field), 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal field.id, json_response["id"]
          assert_equal "テスト圃場", json_response["name"]
        end

        test "should create field" do
          assert_difference("@farm.fields.count", 1) do
            post api_v1_masters_farm_fields_path(@farm), 
                 params: { 
                   field: {
                     name: "新規圃場",
                     area: 100.0,
                     daily_fixed_cost: 500.0
                   }
                 },
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規圃場", json_response["name"]
          assert_equal @farm.id, json_response["farm_id"]
        end

        test "should update field" do
          field = create(:field, farm: @farm, user: @user, name: "元の名前")

          patch api_v1_masters_field_path(field), 
                params: { 
                  field: {
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

        test "should destroy field" do
          field = create(:field, farm: @farm, user: @user)

          assert_difference("@farm.fields.count", -1) do
            delete api_v1_masters_field_path(field), 
                   headers: { 
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :no_content
        end

        test "cannot access field that belongs to other user's farm" do
          other_user = create(:user)
          other_farm = create(:farm, :user_owned, user: other_user)
          other_field = create(:field, farm: other_farm, user: other_user)

          # show
          get api_v1_masters_field_path(other_field),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }
          assert_response :not_found

          # update
          patch api_v1_masters_field_path(other_field),
                params: {
                  field: { name: "更新されない" }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }
          assert_response :not_found

          # destroy
          delete api_v1_masters_field_path(other_field),
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          assert_response :not_found
        end
      end
    end
  end
end
