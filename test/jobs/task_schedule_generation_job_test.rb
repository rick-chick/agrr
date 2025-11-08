require 'test_helper'

class TaskScheduleGenerationJobTest < ActiveJob::TestCase
  class StubGenerator
    attr_reader :received_args

    def initialize(behavior: :success)
      @behavior = behavior
    end

    def generate!(**args)
      @received_args = args
      case @behavior
      when :weather_missing
        raise TaskScheduleGeneratorService::WeatherDataMissingError, 'missing weather data'
      when :progress_missing
        raise TaskScheduleGeneratorService::ProgressDataMissingError, 'missing progress data'
      end
    end
  end

  setup do
    @plan = create(:cultivation_plan)
    @plan.update!(predicted_weather_data: { 'data' => [] })
  end

  test 'perform delegates to TaskScheduleGeneratorService' do
    job = TaskScheduleGenerationJob.new
    job.cultivation_plan_id = @plan.id
    stub_generator = StubGenerator.new
    job.task_schedule_generator = stub_generator

    job.perform(**job.job_arguments)

    assert_equal({ cultivation_plan_id: @plan.id }, stub_generator.received_args)
  end

  test 'perform handles known generator errors gracefully' do
    job = TaskScheduleGenerationJob.new
    job.cultivation_plan_id = @plan.id
    stub_generator = StubGenerator.new(behavior: :weather_missing)
    job.task_schedule_generator = stub_generator

    assert_nothing_raised do
      job.perform(**job.job_arguments)
    end
  end
end

