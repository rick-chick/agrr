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

      test "ai_create should parse npk string and create fertilize when agrr returns direct format" do
        # agrrコマンドが実際に返す形式（トップレベルにname, npkなどが直接ある）
        agrr_output = {
          "name" => "尿素",
          "npk" => "46-0-0",
          "manufacturer" => "Various manufacturers",
          "product_type" => "化学肥料",
          "package_size" => "25kg",
          "description" => "尿素は、窒素を主成分とする化学肥料",
          "usage" => "基肥・追肥に使用可能",
          "application_rate" => "1㎡あたり10-30g",
          "link" => nil
        }.to_json

        # agrr_clientの出力をモック
        Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
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
          assert_equal "25kg", json_response["package_size"]
        end
      end

      test "ai_create should handle package_size from agrr" do
        agrr_output = {
          "name" => "リン酸一安",
          "npk" => "0-18-0",
          "package_size" => "20kg",
          "description" => "リン酸肥料",
          "usage" => "基肥として使用",
          "application_rate" => "1㎡あたり15-40g"
        }.to_json

        Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
          post api_v1_fertilizes_ai_create_path, 
               params: { name: "リン酸一安" },
               headers: { "Accept" => "application/json" }
          
          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "20kg", json_response["package_size"]
        end
      end

      test "ai_create should handle nil package_size from agrr" do
        agrr_output = {
          "name" => "リン酸一安",
          "npk" => "0-18-0",
          "package_size" => nil,
          "description" => "リン酸肥料",
          "usage" => "基肥として使用",
          "application_rate" => "1㎡あたり15-40g"
        }.to_json

        Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
          post api_v1_fertilizes_ai_create_path, 
               params: { name: "リン酸一安" },
               headers: { "Accept" => "application/json" }
          
          assert_response :created
          json_response = JSON.parse(response.body)
          assert_nil json_response["package_size"]
        end
      end

      test "ai_create should update existing fertilize with package_size from agrr" do
        # 既存の肥料を作成
        existing = create(:fertilize, name: "尿素", is_reference: false, package_size: "20kg")
        
        agrr_output = {
          "name" => "尿素",
          "npk" => "46-0-0",
          "package_size" => "25kg",
          "description" => "尿素は、窒素を主成分とする化学肥料",
          "usage" => "基肥・追肥に使用可能",
          "application_rate" => "1㎡あたり10-30g"
        }.to_json

        Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
          post api_v1_fertilizes_ai_create_path, 
               params: { name: "尿素" },
               headers: { "Accept" => "application/json" }
          
          assert_response :ok
          json_response = JSON.parse(response.body)
          assert json_response["success"]
          assert_equal "25kg", json_response["package_size"]
          
          # DBを確認
          existing.reload
          assert_equal "25kg", existing.package_size
        end
      end

      test "ai_create should handle fertilize key format" do
        # agrrコマンドがfertilizeキーでラップした形式を返す場合
        agrr_output = {
          "fertilize" => {
            "name" => "尿素",
            "n" => 46.0,
            "p" => nil,
            "k" => nil,
            "manufacturer" => "Various manufacturers",
            "product_type" => "化学肥料",
            "package_size" => "25kg",
            "description" => "尿素は、窒素を主成分とする化学肥料",
            "usage" => "基肥・追肥に使用可能",
            "application_rate" => "1㎡あたり10-30g",
            "link" => nil
          },
          "success" => true
        }.to_json

        Open3.stub :capture3, [agrr_output, "", OpenStruct.new(success?: true)] do
          post api_v1_fertilizes_ai_create_path, 
               params: { name: "尿素" },
               headers: { "Accept" => "application/json" }
          
          assert_response :created
          json_response = JSON.parse(response.body)
          assert json_response["success"]
          assert_equal "尿素", json_response["fertilize_name"]
          assert_equal "25kg", json_response["package_size"]
        end
      end

      test "ai_create should handle daemon not running error" do
        error_output = "Traceback (most recent call last):\nFileNotFoundError: [Errno 2] No such file or directory\n"

        Open3.stub :capture3, ["", error_output, OpenStruct.new(success?: false)] do
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
end

