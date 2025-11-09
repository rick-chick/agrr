require 'test_helper'

class AgrrScheduleGatewayTest < ActiveSupport::TestCase
  class StubAgrrService
    attr_reader :received_args, :stage_file_content, :tasks_file_content
    attr_accessor :response

    def initialize
      @response = {
        'task_schedules' => [
          {
            'task_id' => 'agrr-task-1',
            'name' => '播種',
            'gdd_trigger' => 240.5,
            'gdd_tolerance' => 12.0
          }
        ]
      }.to_json
    end

    def schedule(crop_name:, variety:, stage_requirements:, agricultural_tasks:, output: nil, json: true)
      @received_args = {
        crop_name: crop_name,
        variety: variety,
        stage_requirements_path: stage_requirements,
        agricultural_tasks_path: agricultural_tasks,
        output: output,
        json: json
      }

      @stage_file_content = File.read(stage_requirements)
      @tasks_file_content = File.read(agricultural_tasks)

      response
    end
  end

  def setup
    @gateway = Agrr::ScheduleGateway.new
    @stub_service = StubAgrrService.new
    @gateway.instance_variable_set(:@agrr_service, @stub_service)

    @stage_requirements = [
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

    @agricultural_tasks = [
      {
        'task_id' => '1',
        'name' => '播種',
        'description' => '直播で播種する',
        'time_per_sqm' => 0.12,
        'weather_dependency' => 'medium'
      }
    ]
  end

  test 'generate delegates to agrr service and preserves gdd trigger in response' do
    result = @gateway.generate(
      crop_name: 'トマト',
      variety: '一般',
      stage_requirements: @stage_requirements,
      agricultural_tasks: @agricultural_tasks
    )

    assert_not_nil @stub_service.received_args, 'AGRR service should be invoked'
    assert_equal 'トマト', @stub_service.received_args[:crop_name]
    assert @stub_service.received_args[:json], 'schedule requests must be JSON'

    stage_json = JSON.parse(@stub_service.stage_file_content)
    assert_equal 240, stage_json.first.dig('thermal', 'required_gdd')

    tasks_json = JSON.parse(@stub_service.tasks_file_content)
    assert_equal '播種', tasks_json.first['name']

    schedule_item = result['task_schedules'].first
    assert_in_delta 240.5, schedule_item['gdd_trigger'], 1e-6
    assert_in_delta 12.0, schedule_item['gdd_tolerance'], 1e-6
  end
end

