# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

module Api
  module V1
    module PublicPlans
      class WizardControllerTest < ActionDispatch::IntegrationTest
        include ActiveJob::TestHelper

        setup do
          @weather_location = create(:weather_location)
          @jp_farm = create(:farm, :reference, region: "jp", weather_location: @weather_location)
          @us_farm = create(:farm, :reference, region: "us", weather_location: @weather_location)
          @jp_crop = create(:crop, :reference, region: "jp")
          @us_crop = create(:crop, :reference, region: "us")
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
      end
    end
  end
end
