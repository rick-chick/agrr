# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"
require "action_cable/test_helper"
require "support/agrr_mock_helper"

module Api
  module V1
    module PublicPlans
      class WizardControllerTest < ActionDispatch::IntegrationTest
        include ActiveJob::TestHelper
        include ActionCable::TestHelper
        include AgrrMockHelper

        setup do
          @weather_location = create(:weather_location)
          @jp_farm = create(:farm, :reference, region: "jp", weather_location: @weather_location)
          @us_farm = create(:farm, :reference, region: "us", weather_location: @weather_location)
          @jp_crop = create(:crop, :reference, :with_stages, region: "jp")
          @us_crop = create(:crop, :reference, :with_stages, region: "us")

          # AGRRのモックを有効化
          stub_fetch_weather_data
          stub_fetch_crop_info
          stub_weather_prediction

          # テスト用の気象データを作成（過去15年分）
          create_weather_data_for_location(@weather_location, 15.years.ago.to_date, Date.current)
        end

        def create_weather_data_for_location(weather_location, start_date, end_date)
          weather_records = []
          (start_date..end_date).each do |date|
            weather_records << {
              weather_location_id: weather_location.id,
              date: date,
              temperature_max: 20.0 + rand(-10..10),
              temperature_min: 5.0 + rand(-5..5),
              temperature_mean: 12.5 + rand(-3..3),
              precipitation: rand(0..15),
              sunshine_hours: rand(4..10),
              wind_speed: rand(2..8),
              weather_code: rand(1..10),
              created_at: Time.current,
              updated_at: Time.current
            }

            # メモリ使用量を抑えるため、1000件ごとにinsert
            if weather_records.size >= 1000
              WeatherDatum.insert_all(weather_records)
              weather_records = []
            end
          end
          WeatherDatum.insert_all(weather_records) unless weather_records.empty?
        end

        test "returns farms filtered by region" do
          get "/api/v1/public_plans/farms", params: { region: "jp" }

          assert_response :success
          json_response = JSON.parse(response.body)
          farm_ids = json_response.map { |farm| farm["id"] }
          assert_includes farm_ids, @jp_farm.id
          assert_not_includes farm_ids, @us_farm.id
        end

        test "returns farm sizes list" do
          get "/api/v1/public_plans/farm_sizes"

          assert_response :success
          json_response = JSON.parse(response.body)
          home_garden = json_response.find { |item| item["id"] == "home_garden" }
          assert_not_nil home_garden
          assert_equal 30, home_garden["area_sqm"]
        end

        test "returns crops scoped to farm region" do
          get "/api/v1/public_plans/crops", params: { farm_id: @jp_farm.id }

          assert_response :success
          json_response = JSON.parse(response.body)
          crop_ids = json_response.map { |crop| crop["id"] }
          assert_includes crop_ids, @jp_crop.id
          assert_not_includes crop_ids, @us_crop.id
        end

        test "creates plan and enqueues job chain" do
          assert_enqueued_with(job: ChainedJobRunnerJob) do
            post "/api/v1/public_plans/plans", params: {
              farm_id: @jp_farm.id,
              farm_size_id: "home_garden",
              crop_ids: [@jp_crop.id]
            }
          end

          assert_response :success
          json_response = JSON.parse(response.body)
          plan = ::CultivationPlan.find(json_response["plan_id"])
          assert_equal "public", plan.plan_type
          assert_equal 30, plan.total_area
        end

        # Angular は Content-Type: application/json で body を送る。params に渡ることを確認（原因Aの否定）。
        test "creates plan when POST body is JSON like Angular client" do
          assert_enqueued_with(job: ChainedJobRunnerJob) do
            post "/api/v1/public_plans/plans",
              params: { farm_id: @jp_farm.id, farm_size_id: "home_garden", crop_ids: [@jp_crop.id] }.to_json,
              headers: { "Content-Type" => "application/json", "ACCEPT" => "application/json" }
          end
          assert_response :success
          json_response = JSON.parse(response.body)
          assert json_response["plan_id"].present?, "response must include plan_id"
          plan = ::CultivationPlan.find(json_response["plan_id"])
          assert_equal "public", plan.plan_type
        end

        # RED検証: farm_size_id が Integer（例: area_sqm の 30）で送られると size[:id] == 30 が false で 422 になる。
        # その原因が真なら「201 と plan_id が返る」テストは失敗する（RED）。
        test "returns success when farm_size_id is sent as integer matching area_sqm" do
          post "/api/v1/public_plans/plans", params: {
            farm_id: @jp_farm.id,
            farm_size_id: 30, # home_garden の area_sqm。現状は id が "home_garden" なので一致せず 422 になる
            crop_ids: [@jp_crop.id]
          }
          assert_response :success, "farm_size_id as integer (30) should be accepted when it matches home_garden area_sqm"
          json_response = JSON.parse(response.body)
          plan = ::CultivationPlan.find(json_response["plan_id"])
          assert_equal 30, plan.total_area
        end

        # RED検証: 計画作成後にジョブチェーンが実行され、OptimizationChannel経由でブロードキャストが行われること
        # ActionCableが正しく実装されていない場合、このテストは失敗する（RED）。
        test "creates plan and broadcasts progress via OptimizationChannel" do
          # ジョブの実行を許可
          perform_enqueued_jobs do
            post "/api/v1/public_plans/plans", params: {
              farm_id: @jp_farm.id,
              farm_size_id: "home_garden",
              crop_ids: [@jp_crop.id]
            }
          end

          assert_response :success
          json_response = JSON.parse(response.body)
          plan = ::CultivationPlan.find(json_response["plan_id"])

          # OptimizationChannel経由でブロードキャストが行われたことを検証
          # ジョブチェーン実行中にフェーズ更新で複数のブロードキャストが行われるはず
          # RED: ActionCableが正しく実装されていない場合、このアサーションは失敗する
          assert_broadcasts OptimizationChannel.broadcasting_for(plan), 9
        end
      end
    end
  end
end
