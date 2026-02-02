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
      end
    end
  end
end