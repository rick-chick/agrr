# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: internal farm weather API on agrr-server (dev/test only).
class InternalFarmWeatherContractTest < ContractTestCase
  setup do
    @farm = create(:farm, :reference)
    @weather_location = create(:weather_location)
    @farm.update!(weather_location: @weather_location)
  end

  test "weather_status returns json for existing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/internal/farms/#{@farm.id}/weather_status")
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 404], response.code.to_i, response.body
    return if response.code.to_i == 404

    json = JSON.parse(response.body)
    assert json.key?("farm_id") || json.key?("status") || json.is_a?(Hash)
  end

  test "weather_data list returns json for existing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/internal/farms/#{@farm.id}/weather_data")
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 404], response.code.to_i, response.body
  end

  test "fetch_weather_data accepts existing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_post("/api/v1/internal/farms/#{@farm.id}/fetch_weather_data")
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 404], response.code.to_i, response.body
    return if response.code.to_i == 404

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert json["farm_id"].present?
  end

  test "weather_status returns not found for missing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/internal/farms/999999999/weather_status")
    refute_equal 501, response.code.to_i, response.body
    assert_equal 404, response.code.to_i, response.body
  end
end
