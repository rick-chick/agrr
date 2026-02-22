# frozen_string_literal: true

require 'test_helper'

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataPerformInteractorTest < ActiveSupport::TestCase
        setup do
          @input_dto = {
            latitude: 35.6762,
            longitude: 139.6503,
            start_date: Date.new(2025, 1, 1),
            end_date: Date.new(2025, 1, 7),
            farm_id: 1,
            cultivation_plan_id: 1,
            channel_class: 'test',
            current_time: Time.current
          }
          @weather_data_gateway = mock('weather_data_gateway')
          @farm_gateway = mock('farm_gateway')
          @cultivation_plan_gateway = mock('cultivation_plan_gateway')
          @agrr_weather_gateway = mock('agrr_weather_gateway')
          @presenter = mock('presenter')
  @presenter.stubs(:info)
  @presenter.stubs(:warn)
  @presenter.stubs(:debug)
  @presenter.stubs(:error)
          @interactor = FetchWeatherDataPerformInteractor.new(
            weather_data_gateway: @weather_data_gateway,
            farm_gateway: @farm_gateway,
            cultivation_plan_gateway: @cultivation_plan_gateway,
            agrr_weather_gateway: @agrr_weather_gateway,
            presenter: @presenter,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new
          )
        end

        test 'sufficient data exists でスキップ' do
          @cultivation_plan_gateway.expects(:update_phase).with(1, "phase_fetching_weather", "test")
          weather_location = mock('weather_location')
          weather_location.stubs(:id).returns(1)
          @weather_data_gateway.expects(:find_weather_location_by_coordinates).with(latitude: 35.6762, longitude: 139.6503).returns(weather_location)
          @weather_data_gateway.expects(:weather_data_count).with(weather_location_id: 1, start_date: @input_dto[:start_date], end_date: @input_dto[:end_date]).returns(6)
          @farm_gateway.expects(:increment_weather_data_progress).with(1)
          @farm_gateway.stubs(:get_weather_data_progress).with(1).returns(50)
          @farm_gateway.stubs(:get_weather_data_fetched_years).with(1).returns(1)
          @farm_gateway.stubs(:get_weather_data_total_years).with(1).returns(2)
          @presenter.stubs(:info)
          @presenter.stubs(:debug)
          @presenter.stubs(:warn)

          @interactor.execute(input_dto: @input_dto)
        end

        test 'fetch & upsert success' do
          @cultivation_plan_gateway.expects(:update_phase).with(1, "phase_fetching_weather", "test")
          @cultivation_plan_gateway.expects(:update_phase).with(1, "phase_weather_data_fetched", "test")
          farm_entity = mock('farm_entity')
          farm_entity.stubs(:region).returns('jp')
          weather_location = mock('weather_location')
          weather_location.stubs(:id).returns(1)
          weather_data = {
            'location' => { 'latitude' => 35.6762, 'longitude' => 139.6503, 'elevation' => 50.0, 'timezone' => 'Asia/Tokyo' },
            'data' => (1..7).map { |day| { 
              'time' => "2025-01-#{'%02d' % day}", 
              'temperature_2m_max' => 20.0, 
              'temperature_2m_min' => 10.0, 
              'temperature_2m_mean' => 15.0, 
              'precipitation_sum' => 0.0, 
              'sunshine_hours' => 6.0, 
              'wind_speed_10m' => 3.0, 
              'weather_code' => 0 
            } }
          }
          @farm_gateway.expects(:find_by_id).with(1).returns(farm_entity)
          @weather_data_gateway.expects(:find_weather_location_by_coordinates).with(latitude: 35.6762, longitude: 139.6503).returns(nil)
          @agrr_weather_gateway.expects(:fetch_by_date_range).with(latitude: 35.6762, longitude: 139.6503, start_date: @input_dto[:start_date], end_date: @input_dto[:end_date], data_source: 'jma').returns(weather_data)
          @weather_data_gateway.expects(:find_or_create_weather_location).with(latitude: 35.6762, longitude: 139.6503, elevation: 50.0, timezone: 'Asia/Tokyo').returns(weather_location)
          @farm_gateway.expects(:update_weather_location_id).with(1, 1)
          @weather_data_gateway.expects(:upsert_weather_data!).with do |args|
            args[:weather_data_dtos].is_a?(Array) && args[:weather_location_id] == 1
          end
          @farm_gateway.expects(:increment_weather_data_progress).with(1)
          @farm_gateway.stubs(:get_weather_data_progress).with(1).returns(50)
          @farm_gateway.stubs(:get_weather_data_progress).with(1).returns(50)
          @farm_gateway.stubs(:get_weather_data_fetched_years).with(1).returns(1)
          @farm_gateway.stubs(:get_weather_data_total_years).with(1).returns(2)

          @presenter.stubs(:info)
          @presenter.stubs(:debug)
          @presenter.stubs(:warn)

          @interactor.execute(input_dto: @input_dto)
        end

        test 'determine_data_source returns jma for jp region farm' do
          farm = mock('farm')
          farm.stubs(:region).returns('jp')
          @farm_gateway.stubs(:find_by_id).with(1).returns(farm)
          assert_equal 'jma', @interactor.send(:determine_data_source, 1, latitude: 35.0, longitude: 139.0)
        end

        test 'determine_data_source returns noaa for non-jp region farm' do
          farm = mock('farm')
          farm.stubs(:region).returns('us')
          @farm_gateway.stubs(:find_by_id).with(1).returns(farm)
          assert_equal 'noaa', @interactor.send(:determine_data_source, 1, latitude: 40.0, longitude: -74.0)
        end

        test 'determine_data_source returns jma for japan coordinates no farm' do
          @farm_gateway.stubs(:find_by_id).returns(nil)
          assert_equal 'jma', @interactor.send(:determine_data_source, nil, latitude: 35.0, longitude: 139.0)
        end

        test 'determine_data_source returns noaa for non-japan coordinates' do
          @farm_gateway.stubs(:find_by_id).returns(nil)
          assert_equal 'noaa', @interactor.send(:determine_data_source, nil, latitude: 37.0, longitude: 127.0)
        end

        test 'raises on empty data response' do
          @cultivation_plan_gateway.expects(:update_phase).once # start & complete
          weather_location = mock('weather_location')
          weather_location.stubs(:id).returns(1)
          empty_data = {'location' => {'latitude' => 35.6762, 'longitude' => 139.6503, 'elevation' => 50.0, 'timezone' => 'Asia/Tokyo'}, 'data' => []}
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns(empty_data)
          assert_raises(StandardError, 'Weather data missing') { @interactor.execute(input_dto: @input_dto) }
        end

        test 'raises on nil response' do
          @cultivation_plan_gateway.expects(:update_phase).once
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns(nil)
          assert_raises(StandardError, 'invalid or missing') { @interactor.execute(input_dto: @input_dto) }
        end

        test 'raises on non-hash response' do
          @cultivation_plan_gateway.expects(:update_phase).once
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns([])
          assert_raises(StandardError, 'invalid or missing') { @interactor.execute(input_dto: @input_dto) }
        end

        test 'raises on missing location' do
          @cultivation_plan_gateway.expects(:update_phase).once
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          bad_data = {'data' => [{'time' => '2025-01-01', 'temperature_2m_max' => 20}], 'location' => nil}
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns(bad_data)
          assert_raises(StandardError, 'missing location') { @interactor.execute(input_dto: @input_dto) }
        end

        test 'raises on excessive missing data' do
          @cultivation_plan_gateway.expects(:update_phase).once
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          insufficient_data = {'location' => {'latitude' => 35.6762, 'longitude' => 139.6503, 'elevation' => 50, 'timezone' => 'Asia/Tokyo'}, 'data' => Array.new(2) { |i| {'time' => "2025-01-0#{i+1}", 'temperature_2m_max' => 20 } } } # 5/7 missing
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns(insufficient_data)
          assert_raises(StandardError, /exceeds/) { @interactor.execute(input_dto: @input_dto) }
        end

        test 'handles acceptable missing data and upserts' do
          @cultivation_plan_gateway.expects(:update_phase).with(1, 'phase_fetching_weather', 'test').once
          @cultivation_plan_gateway.expects(:update_phase).with(1, 'phase_weather_data_fetched', 'test').once
          weather_location = mock('weather_location')
          weather_location.stubs(:id).returns(1)
          acceptable_data = {'location' => {'latitude' => 35.6762, 'longitude' => 139.6503, 'elevation' => 50, 'timezone' => 'Asia/Tokyo'}, 'data' => Array.new(6) { |i| {'time' => "2025-01-0#{i+1}", 'temperature_2m_max' => 20, 'temperature_2m_min' => 10, 'temperature_2m_mean' => 15, 'precipitation_sum' => 0, 'sunshine_hours' => 6, 'wind_speed_10m' => 3, 'weather_code' => 0 } } } # 1/7 missing OK
          @farm_gateway.stubs(:find_by_id).returns(mock('farm', region: 'jp'))
          @weather_data_gateway.stubs(:find_weather_location_by_coordinates).returns(nil)
          @agrr_weather_gateway.expects(:fetch_by_date_range).returns(acceptable_data)
          @weather_data_gateway.expects(:find_or_create_weather_location).returns(weather_location)
          @farm_gateway.expects(:update_weather_location_id).with(1, 1)
          @weather_data_gateway.expects(:upsert_weather_data!)
          @farm_gateway.expects(:increment_weather_data_progress)
          @farm_gateway.stubs(:get_weather_data_progress).returns(50)
          @farm_gateway.stubs(:get_weather_data_fetched_years).returns(1)
          @farm_gateway.stubs(:get_weather_data_total_years).returns(2)
          @presenter.stubs(:warn)
          @interactor.execute(input_dto: @input_dto)
        end

      end
    end
  end
end
