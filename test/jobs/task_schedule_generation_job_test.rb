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

  class StubChannel
    cattr_accessor :messages

    def self.reset!
      self.messages = []
    end

    def self.broadcast_to(record, payload)
      self.messages ||= []
      self.messages << payload.merge(plan_id: record.id)
    end
  end

  setup do
    @plan = create(:cultivation_plan)
    @plan.update!(predicted_weather_data: { 'data' => [] })
    StubChannel.reset!
  end

  test 'perform delegates to TaskScheduleGeneratorService' do
    job = TaskScheduleGenerationJob.new
    job.cultivation_plan_id = @plan.id
    stub_generator = StubGenerator.new
    job.task_schedule_generator = stub_generator
    job.channel_class = StubChannel

    job.perform(**job.job_arguments)

    assert_equal({ cultivation_plan_id: @plan.id }, stub_generator.received_args)
    @plan.reload
    assert_equal 'completed', @plan.status
    assert_equal 'completed', @plan.optimization_phase
    assert_equal I18n.t('models.cultivation_plan.phases.completed'), @plan.optimization_phase_message
    phases = StubChannel.messages.map { |payload| payload[:phase] }
    assert_equal ['task_schedule_generating', 'completed'], phases
  end

  test 'perform handles known generator errors gracefully' do
    job = TaskScheduleGenerationJob.new
    job.cultivation_plan_id = @plan.id
    stub_generator = StubGenerator.new(behavior: :weather_missing)
    job.task_schedule_generator = stub_generator
    job.channel_class = StubChannel

    error = assert_raises TaskScheduleGeneratorService::WeatherDataMissingError do
      job.perform(**job.job_arguments)
    end
    assert_equal 'missing weather data', error.message
    @plan.reload
    assert_equal 'failed', @plan.status
    assert_equal 'failed', @plan.optimization_phase
    assert_equal I18n.t('models.cultivation_plan.phase_failed.task_schedule_generation'), @plan.optimization_phase_message
    last_payload = StubChannel.messages.last
    assert_equal 'failed', last_payload[:status]
    assert_equal 'failed', last_payload[:phase]
  end
end

