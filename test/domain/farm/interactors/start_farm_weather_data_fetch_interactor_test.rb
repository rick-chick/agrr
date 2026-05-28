# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class StartFarmWeatherDataFetchInteractorTest < DomainLibTestCase
        def build_farm(**overrides)
          defaults = {
            id: 10,
            name: "Test Farm",
            latitude: 35.0,
            longitude: 139.0,
            region: "jp",
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1),
            is_reference: false
          }
          Entities::FarmEntity.new(**defaults.merge(overrides))
        end

        setup do
          @as_of = Date.new(2026, 5, 29)
          @input = Dtos::StartFarmWeatherDataFetchInput.new(farm_id: 10, as_of: @as_of)
          @farm_gateway = mock("farm_gateway")
          @enqueue_port = mock("fetch_weather_data_enqueue_port")
          @interactor = StartFarmWeatherDataFetchInteractor.new(
            farm_gateway: @farm_gateway,
            fetch_weather_data_enqueue_port: @enqueue_port
          )
        end

        test "returns nil without updating or enqueueing when farm lacks coordinates" do
          farm = build_farm(latitude: nil, longitude: 139.0)
          @farm_gateway.expects(:find_by_id).with(10).returns(farm)
          @farm_gateway.expects(:update_weather_progress).never
          @enqueue_port.expects(:enqueue_farm_weather_fetch).never

          assert_nil @interactor.call(@input)
        end

        test "updates progress and enqueues weather fetch blocks when farm has coordinates" do
          farm = build_farm
          expected_attrs = Calculators::FarmWeatherProgressCalculator.start_fetch_attrs(as_of: @as_of)
          expected_blocks = Calculators::FarmWeatherProgressCalculator.weather_fetch_blocks(as_of: @as_of)

          @farm_gateway.expects(:find_by_id).with(10).returns(farm)
          @farm_gateway.expects(:update_weather_progress).with(10, expected_attrs)
          @enqueue_port.expects(:enqueue_farm_weather_fetch).with(
            farm_id: 10,
            latitude: 35.0,
            longitude: 139.0,
            blocks: expected_blocks
          )

          assert_equal farm, @interactor.call(@input)
        end
      end
    end
  end
end
