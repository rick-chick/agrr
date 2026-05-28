# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class RecordFarmWeatherBlockCompletedInteractorTest < DomainLibTestCase
        def build_farm(fetched:, total:, last_broadcast_at: nil)
          Entities::FarmEntity.new(
            id: 5,
            name: "Farm",
            latitude: 35.0,
            longitude: 139.0,
            region: "jp",
            user_id: 1,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1),
            is_reference: false,
            weather_data_fetched_years: fetched,
            weather_data_total_years: total,
            weather_data_status: "fetching",
            last_broadcast_at: last_broadcast_at
          )
        end

        setup do
          @current_time = Time.utc(2026, 5, 29, 12, 0, 0)
          @input = Dtos::RecordFarmWeatherBlockCompletedInput.new(
            farm_id: 5,
            current_time: @current_time
          )
          @farm_gateway = mock("farm_gateway")
          @broadcast_port = mock("farm_refresh_broadcast_port")
        end

        test "returns nil without gateway update when progress already complete" do
          farm = build_farm(fetched: 3, total: 3)
          @farm_gateway.expects(:find_by_id).with(5, include_weather_data_fields: true).returns(farm)
          @farm_gateway.expects(:update_weather_progress).never
          @broadcast_port.expects(:broadcast_farm_weather_progress).never

          interactor = RecordFarmWeatherBlockCompletedInteractor.new(
            farm_gateway: @farm_gateway,
            farm_refresh_broadcast_port: @broadcast_port
          )

          assert_nil interactor.call(@input)
        end

        test "increments fetched years and broadcasts when throttle allows" do
          farm = build_farm(fetched: 0, total: 2, last_broadcast_at: nil)
          updated = build_farm(
            fetched: 1,
            total: 2,
            last_broadcast_at: @current_time
          )
          updated.define_singleton_method(:weather_data_progress) { 50 }
          updated.define_singleton_method(:weather_data_status) { "fetching" }

          expected_attrs, = Calculators::FarmWeatherProgressCalculator.next_after_block(
            fetched: 0,
            total: 2,
            last_broadcast_at: nil,
            current_time: @current_time
          )

          @farm_gateway.expects(:find_by_id).with(5, include_weather_data_fields: true).returns(farm)
          @farm_gateway.expects(:update_weather_progress).with(5, expected_attrs).returns(updated)
          @broadcast_port.expects(:broadcast_farm_weather_progress).with(
            farm_id: 5,
            payload: {
              id: 5,
              weather_data_status: "fetching",
              weather_data_progress: 50,
              weather_data_fetched_years: 1,
              weather_data_total_years: 2
            }
          )

          interactor = RecordFarmWeatherBlockCompletedInteractor.new(
            farm_gateway: @farm_gateway,
            farm_refresh_broadcast_port: @broadcast_port
          )

          assert_equal updated, interactor.call(@input)
        end

        test "updates progress without broadcast port" do
          farm = build_farm(fetched: 0, total: 2)
          updated = build_farm(fetched: 1, total: 2)
          expected_attrs, = Calculators::FarmWeatherProgressCalculator.next_after_block(
            fetched: 0,
            total: 2,
            last_broadcast_at: nil,
            current_time: @current_time
          )

          @farm_gateway.expects(:find_by_id).with(5, include_weather_data_fields: true).returns(farm)
          @farm_gateway.expects(:update_weather_progress).with(5, expected_attrs).returns(updated)

          interactor = RecordFarmWeatherBlockCompletedInteractor.new(farm_gateway: @farm_gateway)

          assert_equal updated, interactor.call(@input)
        end
      end
    end
  end
end
