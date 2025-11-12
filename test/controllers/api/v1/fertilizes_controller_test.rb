# frozen_string_literal: true

require "test_helper"
require "open3"
require "ostruct"

module Api
  module V1
    class FertilizesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = create(:user)
        sign_in_as @user
      end

      teardown do
        Rails.configuration.x.fertilize_ai_gateway = nil
      end

      test "ai_create should parse npk string and create fertilize when agrr returns direct format" do
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: {
            "name" => "尿素",
            "npk" => "46-0-0",
            "manufacturer" => "Various manufacturers",
            "product_type" => "化学肥料",
            "package_size" => "25kg",
            "description" => "尿素は、窒素を主成分とする化学肥料",
            "link" => nil
          },
          error_response: nil
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "尿素" },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        assert json_response["success"]
        assert_equal "尿素", json_response["fertilize_name"]
        assert_equal 46.0, json_response["n"]
        assert_nil json_response["p"]
        assert_nil json_response["k"]
        assert_equal 25.0, json_response["package_size"]
      end

      test "ai_create should handle package_size from agrr" do
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: {
            "name" => "リン酸一安",
            "npk" => "0-18-0",
            "package_size" => "20kg",
            "description" => "リン酸肥料",
            "success" => true
          },
          error_response: nil
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "リン酸一安" },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        assert_equal 20.0, json_response["package_size"]
      end

      test "ai_create should handle nil package_size from agrr" do
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: {
            "name" => "リン酸一安",
            "npk" => "0-18-0",
            "package_size" => nil,
            "description" => "リン酸肥料"
          },
          error_response: nil
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "リン酸一安" },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        assert_nil json_response["package_size"]
      end

      test "ai_create should update existing fertilize with package_size from agrr" do
        # 既存の肥料を作成
        existing = create(:fertilize, :user_owned, user: @user, name: "尿素", package_size: 20.0)
        
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: {
            "name" => "尿素",
            "npk" => "46-0-0",
            "package_size" => "25kg",
            "description" => "尿素は、窒素を主成分とする化学肥料",
            "success" => true
          },
          error_response: nil
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "尿素" },
             headers: { "Accept" => "application/json" }
        
        assert_response :ok
        json_response = JSON.parse(response.body)
        assert json_response["success"]
        assert_equal 25.0, json_response["package_size"]
        
        # DBを確認
        existing.reload
        assert_equal 25.0, existing.package_size
      end

      test "ai_create should handle fertilize key format" do
        # agrrコマンドがfertilizeキーでラップした形式を返す場合
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: {
            "fertilize" => {
              "name" => "尿素",
              "n" => 46.0,
              "p" => nil,
              "k" => nil,
              "manufacturer" => "Various manufacturers",
              "product_type" => "化学肥料",
              "package_size" => "25kg",
              "description" => "尿素は、窒素を主成分とする化学肥料",
              "link" => nil
            },
            "success" => true
          },
          error_response: nil
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "尿素" },
             headers: { "Accept" => "application/json" }
        
        assert_response :created
        json_response = JSON.parse(response.body)
        assert json_response["success"]
        assert_equal "尿素", json_response["fertilize_name"]
        assert_equal 25.0, json_response["package_size"]
      end

      test "ai_create should handle daemon not running error" do
        Rails.configuration.x.fertilize_ai_gateway = FertilizeAiGatewayStub.new(
          success_response: nil,
          error_response: {
            "success" => false,
            "error" => "AGRRサービスが起動していません",
            "code" => "daemon_not_running"
          }
        )

        post api_v1_fertilizes_ai_create_path, 
             params: { name: "尿素" },
             headers: { "Accept" => "application/json" }
        
        assert_response :service_unavailable
        json_response = JSON.parse(response.body)
        assert_includes json_response["error"], "AGRRサービスが起動していません"
      end
    end
  end
end

