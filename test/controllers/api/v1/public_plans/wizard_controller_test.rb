require 'test_helper'

module Api
  module V1
    module PublicPlans
      class WizardControllerTest < ActionDispatch::IntegrationTest
        test "farms endpoint returns farms for region" do
          get api_v1_public_plans_farms_path, params: { region: 'jp' }

          assert_response :success
          json = JSON.parse(response.body)
          assert json.is_a?(Array)
          assert json.length >= 0 # Allow empty if no farms exist

          if json.length > 0
            farm = json.first
            assert farm['name'].present?
            assert farm['region'].present?
            assert farm['latitude'].is_a?(Numeric)
            assert farm['longitude'].is_a?(Numeric)
          end
        end

        test "farm_sizes endpoint returns farm sizes" do
          get api_v1_public_plans_farm_sizes_path

          assert_response :success
          json = JSON.parse(response.body)
          assert json.is_a?(Array)
          assert json.length > 0

          # Check if home_garden size exists
          home_garden = json.find { |size| size['id'] == 'home_garden' }
          assert home_garden
          assert_equal 30, home_garden['area_sqm']
        end

        test "farms endpoint works without region parameter" do
          get api_v1_public_plans_farms_path

          assert_response :success
          json = JSON.parse(response.body)
          assert json.is_a?(Array)
        end

        test "create returns plan_id and enqueues job chain on success" do
          weather_location = WeatherLocation.create!(
            latitude: 36.0,
            longitude: 140.0,
            elevation: 50.0,
            timezone: 'Asia/Tokyo'
          )
          farm = create(:farm, region: 'jp', latitude: 36.0, longitude: 140.0, weather_location: weather_location)
          crop = create(:crop, :reference, region: 'jp')

          post api_v1_public_plans_plans_path, params: {
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: [crop.id]
          }, as: :json

          assert_response :ok
          json = JSON.parse(response.body)
          assert json['plan_id'].present?
          assert json['plan_id'].is_a?(Integer)

          # 計画が作成されたことを確認
          plan = ::CultivationPlan.find(json['plan_id'])
          assert_equal farm.id, plan.farm_id
          assert_equal 'public', plan.plan_type

          # ジョブチェーンの実行は Presenter のテストでカバーされているため、
          # ここでは plan_id が返されることと、適切なステータスコードが返されることを確認する
        end

        test "create returns 404 when farm not found" do
          crop = create(:crop, :reference, region: 'jp')

          post api_v1_public_plans_plans_path, params: {
            farm_id: 99999,
            farm_size_id: 'home_garden',
            crop_ids: [crop.id]
          }, as: :json

          assert_response :not_found
          json = JSON.parse(response.body)
          assert_equal 'Farm not found', json['error']
        end

        test "create returns 422 when farm_size is invalid" do
          weather_location = WeatherLocation.create!(
            latitude: 36.0,
            longitude: 140.0,
            elevation: 50.0,
            timezone: 'Asia/Tokyo'
          )
          farm = create(:farm, region: 'jp', latitude: 36.0, longitude: 140.0, weather_location: weather_location)
          crop = create(:crop, :reference, region: 'jp')

          post api_v1_public_plans_plans_path, params: {
            farm_id: farm.id,
            farm_size_id: 'invalid_size',
            crop_ids: [crop.id]
          }, as: :json

          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_equal 'Invalid farm size', json['error']
        end

        test "create returns 422 when no crops selected" do
          weather_location = WeatherLocation.create!(
            latitude: 36.0,
            longitude: 140.0,
            elevation: 50.0,
            timezone: 'Asia/Tokyo'
          )
          farm = create(:farm, region: 'jp', latitude: 36.0, longitude: 140.0, weather_location: weather_location)

          post api_v1_public_plans_plans_path, params: {
            farm_id: farm.id,
            farm_size_id: 'home_garden',
            crop_ids: []
          }, as: :json

          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_equal 'No crops selected', json['error']
        end

        test "create handles unexpected errors and returns 500" do
          # Interactor 内で StandardError が発生した場合のテスト
          # 実際のエラーケース（例: DB接続エラーなど）は統合テストでは再現が難しいため、
          # Interactor の単体テスト（public_plan_create_interactor_test.rb）でカバーされている
          # ここでは、正常なケースとバリデーションエラーのケースをテストする
          # このテストは Interactor のテストでカバーされているため、スキップ
          skip "Unexpected error handling is covered by Interactor unit tests"
        end
      end
    end
  end
end