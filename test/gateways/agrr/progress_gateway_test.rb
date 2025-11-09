require 'test_helper'

class AgrrProgressGatewayTest < ActiveSupport::TestCase
  class StubAgrrService
    attr_reader :received_args, :crop_file_content, :weather_file_content
    attr_accessor :response

    def initialize
      @response = {
        'progress_records' => [
          {
            'date' => '2025-04-01T00:00:00',
            'cumulative_gdd' => 75.5,
            'total_required_gdd' => 240.0
          }
        ],
        'total_gdd' => 320.0
      }.to_json
    end

    def progress(crop_file:, start_date:, weather_file:)
      @received_args = {
        crop_file: crop_file,
        start_date: start_date,
        weather_file: weather_file
      }

      @crop_file_content = File.read(crop_file)
      @weather_file_content = File.read(weather_file)

      response
    end
  end

  def setup
    @gateway = Agrr::ProgressGateway.new
    @stub_service = StubAgrrService.new
    @gateway.instance_variable_set(:@agrr_service, @stub_service)

    @crop_profile = {
      'crop' => { 'name' => 'トマト', 'variety' => 'アイコ' },
      'stage_requirements' => [
        {
          'stage' => { 'name' => '発芽', 'order' => 1 },
          'thermal' => { 'required_gdd' => 240 },
          'temperature' => {
            'base_temperature' => 8.0,
            'optimal_min' => 15.0,
            'optimal_max' => 28.0,
            'low_stress_threshold' => 5.0,
            'high_stress_threshold' => 32.0,
            'frost_threshold' => -2.0,
            'max_temperature' => 40.0
          }
        }
      ]
    }

    @weather_data = {
      'data' => [
        { 'time' => '2025-04-01T00:00:00', 'temperature_2m_mean' => 16.5 },
        { 'time' => '2025-04-02T00:00:00', 'temperature_2m_mean' => 18.0 }
      ]
    }
  end

  test 'calculate_progress uploads temp files and parses agrr response' do
    crop = Class.new do
      def initialize(profile)
        @profile = profile
      end

      def to_agrr_requirement
        @profile
      end

      def name
        'トマト'
      end
    end.new(@crop_profile)

    result = @gateway.calculate_progress(
      crop: crop,
      start_date: Date.new(2025, 4, 1),
      weather_data: @weather_data
    )

    assert_not_nil @stub_service.received_args, 'AGRR service should be called'
    assert_equal '2025-04-01', @stub_service.received_args[:start_date]

    crop_json = JSON.parse(@stub_service.crop_file_content)
    assert_equal 'トマト', crop_json.dig('crop', 'name')

    weather_json = JSON.parse(@stub_service.weather_file_content)
    assert_equal 2, weather_json['data'].size

    progress = result['progress_records'].first
    assert_in_delta 75.5, progress['cumulative_gdd'], 1e-6
    assert_equal '2025-04-01T00:00:00', progress['date']
  end
end

