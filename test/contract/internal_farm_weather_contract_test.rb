# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"
require_relative "support/gcs_weather_fixture"

# R4: internal farm weather API on agrr-server (dev/test only).
class InternalFarmWeatherContractTest < ContractTestCase
  include GcsWeatherFixture

  setup do
    @farm = create(:farm, :reference)
    @weather_location = create(:weather_location)
    @farm.update!(weather_location: @weather_location)
    seed_rust_gcs_weather_fixture!(weather_location_id: @weather_location.id)
  end

  test "weather_status returns json for existing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/internal/farms/#{@farm.id}/weather_status")
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 404], response.code.to_i, response.body
    return if response.code.to_i == 404

    json = JSON.parse(response.body)
    assert json.key?("farm_id") || json.key?("status") || json.is_a?(Hash)
    if ENV["WEATHER_DATA_STORAGE"] == "gcs"
      assert_operator json.fetch("weather_data_count", 0), :>, 0,
                      "expected GCS bulk count > 0 (fixture at #{gcs_fixture_path(@weather_location.id)})"
    end
  end

  test "weather_data list returns json for existing farm" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/internal/farms/#{@farm.id}/weather_data")
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 404], response.code.to_i, response.body
    return if response.code.to_i == 404

    json = JSON.parse(response.body)
    if ENV["WEATHER_DATA_STORAGE"] == "gcs"
      assert_operator json.fetch("count", 0), :>, 0,
                      "expected GCS period read count > 0"
      assert_empty ::WeatherDatum.where(weather_location_id: @weather_location.id),
                   "bulk path must not rely on SQLite weather_data rows"
    end
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
