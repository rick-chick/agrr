# frozen_string_literal: true

require "test_helper"
require "open3"
require "ostruct"

module Api
  module V1
    class PestsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create(:user)
        sign_in_as @user
        
        # テスト用の作物を作成
        @crop1 = create(:crop, user: @user, name: 'ブロッコリー')
        @crop2 = create(:crop, user: @user, name: 'ほうれん草')
        @crop3 = create(:crop, user: @user, name: 'レタス')
        @reference_crop = create(:crop, :reference, name: 'かぼちゃ', region: 'jp')
      end

      test "ai_create should create pest with affected crops" do
        # agrrコマンドが実際に返す形式
        agrr_output = {
          "success" => true,
          "data" => {
            "pest" => {
              "pest_id" => "test-001",
              "name" => "アオムシ",
              "name_scientific" => "Pieris rapae",
              "family" => "シロチョウ科",
              "order" => "チョウ目",
              "description" => "アオムシは主にキャベツやブロッコリーなどの葉物野菜を食害します",
              "occurrence_season" => "春〜秋",
              "temperature_profile" => {
                "base_temperature" => 10.0,
                "max_temperature" => 30.0
              },
              "thermal_requirement" => {
                "required_gdd" => 300.0,
                "first_generation_gdd" => 150.0
              },
              "control_methods" => [
                {
                  "method_type" => "chemical",
                  "method_name" => "殺虫剤",
                  "description" => "アオムシに効果的な殺虫剤を散布",
                  "timing_hint" => "発生初期に散布"
                }
              ]
            },
            "affected_crops" => []
          }
        }.to_json

        # PestsControllerのfetch_pest_info_from_agrrをモック
        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) do |pest_name, affected_crops|
            JSON.parse(agrr_output)
          end
        end

        assert_difference "Pest.count", +1 do
          post api_v1_pests_ai_create_path, 
               params: { 
                 name: "アオムシ",
                 affected_crops: [
                   { "crop_id" => @crop1.id.to_s, "crop_name" => "ブロッコリー" },
                   { "crop_id" => @crop2.id.to_s, "crop_name" => "ほうれん草" }
                 ]
               },
               headers: { "Accept" => "application/json" }
        end

        assert_response :created
        json_response = JSON.parse(response.body)
        assert json_response["success"]
        assert_equal "アオムシ", json_response["pest_name"]
        assert_equal "シロチョウ科", json_response["family"]
        
        # 害虫が作成されたことを確認
        pest = Pest.find(json_response["pest_id"])
        assert_not_nil pest
        assert_equal @user.id, pest.user_id
        assert_not pest.is_reference
        assert_equal 2, pest.crops.count
        assert pest.crops.include?(@crop1)
        assert pest.crops.include?(@crop2)
      end

      test "ai_create should handle reference crops" do
        agrr_output = {
          "success" => true,
          "data" => {
            "pest" => {
              "pest_id" => "test-002",
              "name" => "テスター",
              "name_scientific" => "Testus insectus",
              "family" => "テスト科",
              "order" => "テスト目",
              "description" => "テスト害虫",
              "occurrence_season" => "春〜秋",
              "temperature_profile" => {
                "base_temperature" => 10.0,
                "max_temperature" => 30.0
              },
              "thermal_requirement" => {
                "required_gdd" => 300.0,
                "first_generation_gdd" => 150.0
              },
              "control_methods" => []
            },
            "affected_crops" => []
          }
        }.to_json

        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) { |pest_name, affected_crops| JSON.parse(agrr_output) }
        end

        post api_v1_pests_ai_create_path, 
             params: { 
               name: "テスター",
               affected_crops: [
                 { "crop_id" => @reference_crop.id.to_s, "crop_name" => "かぼちゃ" }
               ]
             },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        
        # 参照作物も関連付けできることを確認
        pest = Pest.find(json_response["pest_id"])
        assert_equal 1, pest.crops.count
        assert pest.crops.include?(@reference_crop)
      end

      test "ai_create should handle empty affected_crops" do
        agrr_output = {
          "success" => true,
          "data" => {
            "pest" => {
              "pest_id" => "test-003",
              "name" => "テスター2",
              "name_scientific" => "Testus insectus",
              "family" => "テスト科",
              "order" => "テスト目",
              "description" => "テスト害虫",
              "occurrence_season" => "春〜秋",
              "temperature_profile" => nil,
              "thermal_requirement" => nil,
              "control_methods" => []
            },
            "affected_crops" => []
          }
        }.to_json

        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) { |pest_name, affected_crops| JSON.parse(agrr_output) }
        end

        post api_v1_pests_ai_create_path, 
             params: { name: "テスター2" },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        
        # 作物なしでも作成できることを確認
        pest = Pest.find(json_response["pest_id"])
        assert_equal 0, pest.crops.count
      end

      test "ai_create should handle daemon not running error" do
        error_output = {
          "success" => false,
          "error" => "AGRRサービスが起動していません",
          "code" => "daemon_not_running"
        }.to_json

        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) { |pest_name, affected_crops| JSON.parse(error_output) }
        end

        post api_v1_pests_ai_create_path, 
             params: { name: "アオムシ" },
             headers: { "Accept" => "application/json" }
        
        assert_response :service_unavailable
        json_response = JSON.parse(response.body)
        assert_includes json_response["error"], "AGRRサービスが起動していません"
      end

      test "ai_create should prevent accessing other user's crops" do
        other_user = create(:user)
        other_crop = create(:crop, user: other_user, name: '他人の作物')
        
        agrr_output = {
          "success" => true,
          "data" => {
            "pest" => {
              "pest_id" => "test-004",
              "name" => "テスター3",
              "name_scientific" => "Testus insectus",
              "family" => "テスト科",
              "order" => "テスト目",
              "description" => "テスト害虫",
              "occurrence_season" => "春〜秋",
              "temperature_profile" => nil,
              "thermal_requirement" => nil,
              "control_methods" => []
            },
            "affected_crops" => []
          }
        }.to_json

        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) { |pest_name, affected_crops| JSON.parse(agrr_output) }
        end

        post api_v1_pests_ai_create_path, 
             params: { 
               name: "テスター3",
               affected_crops: [
                 { "crop_id" => @crop1.id.to_s, "crop_name" => "ブロッコリー" },
                 { "crop_id" => other_crop.id.to_s, "crop_name" => "他人の作物" }
               ]
             },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        
        # 自分の作物のみ関連付けられていることを確認
        pest = Pest.last
        assert_equal 1, pest.crops.count
        assert pest.crops.include?(@crop1)
        assert_not pest.crops.include?(other_crop)
      end

      test "ai_create should reject anonymous user instead of sharing anonymous pest records" do
        # サインインを解除して匿名ユーザー状態にする
        cookies.delete(:session_id)
        Session.delete_all
        @integration_session.reset! if defined?(@integration_session) && @integration_session.respond_to?(:reset!)
        anonymous = User.anonymous_user
        create(:pest, :user_owned, user: anonymous, name: "匿名害虫")

        agrr_output = {
          "success" => true,
          "data" => {
            "pest" => {
              "pest_id" => "anon-001",
              "name" => "匿名害虫",
              "name_scientific" => "Anon pest",
              "family" => "Anon family",
              "order" => "Anon order",
              "description" => "匿名で上書きされてはいけない",
              "occurrence_season" => "通年",
              "temperature_profile" => nil,
              "thermal_requirement" => nil,
              "control_methods" => []
            },
            "affected_crops" => []
          }
        }.to_json

        Api::V1::PestsController.class_eval do
          define_method(:fetch_pest_info_from_agrr) { |_name, _affected_crops| JSON.parse(agrr_output) }
        end

        assert_no_difference "Pest.count" do
          post api_v1_pests_ai_create_path,
               params: { name: "匿名害虫" },
               headers: { "Accept" => "application/json" }
        end

        assert_response :unauthorized

        # 匿名ユーザーの既存レコードが書き換わらないことを期待（現状は上書きされる）
        assert_equal "匿名害虫", Pest.find_by(name: "匿名害虫", user: anonymous)&.name
      end
    end
  end
end
