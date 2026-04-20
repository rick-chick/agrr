# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module PublicPlans
      class EntryScheduleControllerTest < ActionDispatch::IntegrationTest
        setup do
          @weather_location = create(:weather_location)
          @farm = create(:farm, :reference, region: "jp", weather_location: @weather_location)
          @crop = create(:crop, :reference, :with_stages, region: "jp")
        end

        test "entry_schedule farms returns reference farms as json array" do
          get api_v1_public_plans_entry_schedule_farms_path, params: { region: "jp" }

          assert_response :success
          json = JSON.parse(response.body)
          assert json.is_a?(Array)
          ids = json.map { |f| f["id"] }
          assert_includes ids, @farm.id
        end

        test "entry_schedule crops returns crops when weather is stubbed" do
          payload = sample_prediction_payload
          stub_weather_prediction!(payload) do
            get api_v1_public_plans_entry_schedule_crops_path, params: { farm_id: @farm.id }
          end

          assert_response :success
          body = JSON.parse(response.body)
          assert_equal @farm.id, body["farm"]["id"]
          assert body["crops"].is_a?(Array)
          crop_row = body["crops"].find { |c| c["id"] == @crop.id }
          assert crop_row
          assert crop_row["reason_summary"].present?
        end

        test "entry_schedule show returns crop detail" do
          payload = sample_prediction_payload
          stub_weather_prediction!(payload) do
            get api_v1_public_plans_entry_schedule_crop_path(@crop.id), params: { farm_id: @farm.id }
          end

          assert_response :success
          body = JSON.parse(response.body)
          assert_equal @crop.id, body["crop"]["id"]
          assert body["crop"]["crop_stages"].is_a?(Array)
        end

        test "crops returns 422 when farm has no weather_location" do
          @farm.update!(weather_location_id: nil)

          get api_v1_public_plans_entry_schedule_crops_path, params: { farm_id: @farm.id }

          assert_response :unprocessable_entity
        end

        test "crops returns 404 when farm_id is missing" do
          get api_v1_public_plans_entry_schedule_crops_path

          assert_response :not_found
        end

        private

        def sample_prediction_payload
          rows = (1..5).map do |d|
            {
              "time" => "2026-04-#{d.to_s.rjust(2, '0')}",
              "temperature_2m_min" => 5.0,
              "temperature_2m_max" => 28.0,
              "temperature_2m_mean" => 19.0
            }
          end
          {
            "data" => rows,
            "generated_at" => Time.zone.now.iso8601,
            "prediction_end_date" => "2026-12-31"
          }
        end

        def stub_weather_prediction!(payload_hash)
          weather_double = Object.new
          weather_double.define_singleton_method(:get_existing_prediction) do |**_|
            { data: payload_hash }
          end
          weather_double.define_singleton_method(:predict_for_farm) do |**_|
            true
          end
          Domain::WeatherData::Interactors::WeatherPredictionInteractor.stub(:new, weather_double) do
            yield
          end
        end
      end
    end
  end
end
