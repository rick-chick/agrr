require 'test_helper'

class TaskScheduleGeneratorServiceTest < ActiveSupport::TestCase
  class StubScheduleGateway
    attr_reader :called

    def initialize
      @called = false
    end

    def generate(*)
      @called = true
      {}
    end
  end

  class StubFertilizeGateway
    attr_reader :called

    def initialize
      @called = false
    end

    def plan(*)
      @called = true
      {}
    end
  end

  class StubProgressGateway
    attr_reader :received_payloads

    def initialize(response)
      @response = response
      @received_payloads = []
    end

    def calculate_progress(crop:, start_date:, weather_data:)
      @received_payloads << {
        crop: crop,
        start_date: start_date,
        weather_data: weather_data
      }
      @response
    end
  end

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @plan = create(:cultivation_plan, farm: @farm, user: @user)
    @plan.update!(predicted_weather_data: mocked_weather_data)

    @crop = create(:crop, :with_stages, user: @user, name: 'トマト', variety: 'アイコ')
    @soil_task = create(:agricultural_task, :soil_preparation)
    @planting_task = create(:agricultural_task, :planting)
    create(
      :crop_task_template,
      crop: @crop,
      agricultural_task: @soil_task,
      source_agricultural_task_id: @soil_task.id,
      name: @soil_task.name,
      description: @soil_task.description,
      time_per_sqm: @soil_task.time_per_sqm,
      weather_dependency: @soil_task.weather_dependency,
      required_tools: @soil_task.required_tools,
      skill_level: @soil_task.skill_level,
      task_type: @soil_task.task_type,
      task_type_id: @soil_task.task_type_id,
      is_reference: @soil_task.is_reference
    )
    create(
      :crop_task_template,
      crop: @crop,
      agricultural_task: @planting_task,
      source_agricultural_task_id: @planting_task.id,
      name: @planting_task.name,
      description: @planting_task.description,
      time_per_sqm: @planting_task.time_per_sqm,
      weather_dependency: @planting_task.weather_dependency,
      required_tools: @planting_task.required_tools,
      skill_level: @planting_task.skill_level,
      task_type: @planting_task.task_type,
      task_type_id: @planting_task.task_type_id,
      is_reference: @planting_task.is_reference
    )

    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop, name: @crop.name, variety: @crop.variety)
    @plan_field = create(:cultivation_plan_field, cultivation_plan: @plan)
    @field_cultivation = create(:field_cultivation,
                                cultivation_plan: @plan,
                                cultivation_plan_field: @plan_field,
                                cultivation_plan_crop: @plan_crop,
                                area: 120.0,
                                start_date: Date.new(2025, 4, 1),
                                completion_date: Date.new(2025, 8, 1))

    create(:crop_task_schedule_blueprint,
           crop: @crop,
           agricultural_task: @soil_task,
           stage_order: 1,
           stage_name: '土壌準備',
           gdd_trigger: BigDecimal('0.0'),
           gdd_tolerance: BigDecimal('5.0'),
           priority: 1,
           source: 'agrr_schedule',
           weather_dependency: 'low',
           time_per_sqm: BigDecimal('0.1'))

    create(:crop_task_schedule_blueprint,
           :fertilizer,
           :without_agricultural_task,
           crop: @crop,
           stage_order: 0,
           stage_name: '定植前',
           gdd_trigger: BigDecimal('0.0'),
           gdd_tolerance: BigDecimal('5.0'),
           priority: 1,
           source_agricultural_task_id: 11_001)

    create(:crop_task_schedule_blueprint,
           :fertilizer,
           :without_agricultural_task,
           crop: @crop,
           task_type: TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE,
           stage_order: 2,
           stage_name: '生育期',
           gdd_trigger: BigDecimal('160.0'),
           gdd_tolerance: BigDecimal('10.0'),
           priority: 2,
           amount: BigDecimal('4.0'),
           source_agricultural_task_id: 11_002)
  end

  test 'generate! creates schedules from blueprints and skips agrr gateways' do
    schedule_gateway = StubScheduleGateway.new
    fertilize_gateway = StubFertilizeGateway.new
    progress_gateway = StubProgressGateway.new(progress_response)

    service = TaskScheduleGeneratorService.new(
      schedule_gateway: schedule_gateway,
      fertilize_gateway: fertilize_gateway,
      progress_gateway: progress_gateway
    )

    assert_difference -> { TaskSchedule.count }, 2 do
      assert_difference -> { TaskScheduleItem.count }, 3 do
        service.generate!(cultivation_plan_id: @plan.id)
      end
    end

    general_schedule = TaskSchedule.find_by!(cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'general')
    fertilizer_schedule = TaskSchedule.find_by!(cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'fertilizer')

    general_item = general_schedule.task_schedule_items.find_by!(task_type: TaskScheduleItem::FIELD_WORK_TYPE)
    assert_equal @soil_task, general_item.agricultural_task
    assert_equal BigDecimal('0.0'), general_item.gdd_trigger
    assert_equal Date.new(2025, 4, 1), general_item.scheduled_date
    assert_equal 'agrr_schedule', general_item.source

    fertilizer_items = fertilizer_schedule.task_schedule_items.order(:priority)
    assert_equal 2, fertilizer_items.count
    assert_equal TaskScheduleItem::BASAL_FERTILIZATION_TYPE, fertilizer_items.first.task_type
    assert_equal Date.new(2025, 4, 1), fertilizer_items.first.scheduled_date
    assert_equal BigDecimal('160.0'), fertilizer_items.second.gdd_trigger
    assert_equal Date.new(2025, 4, 6), fertilizer_items.second.scheduled_date

    refute schedule_gateway.called, 'schedule gateway should not be called when blueprints exist'
    refute fertilize_gateway.called, 'fertilize gateway should not be called when blueprints exist'
  end

  test 'generate! raises TemplateMissingError when crop has no blueprints' do
    @crop.crop_task_schedule_blueprints.delete_all

    schedule_gateway = StubScheduleGateway.new
    fertilize_gateway = StubFertilizeGateway.new
    progress_gateway = StubProgressGateway.new(progress_response)

    service = TaskScheduleGeneratorService.new(
      schedule_gateway: schedule_gateway,
      fertilize_gateway: fertilize_gateway,
      progress_gateway: progress_gateway
    )

    assert_raises TaskScheduleGeneratorService::TemplateMissingError do
      service.generate!(cultivation_plan_id: @plan.id)
    end

    refute schedule_gateway.called
    refute fertilize_gateway.called
  end

  test 'generate! raises error when progress has no records' do
    progress_gateway = StubProgressGateway.new(progress_response.merge('progress_records' => []))
    service = TaskScheduleGeneratorService.new(
      schedule_gateway: StubScheduleGateway.new,
      fertilize_gateway: StubFertilizeGateway.new,
      progress_gateway: progress_gateway
    )

    assert_raises TaskScheduleGeneratorService::ProgressDataMissingError do
      service.generate!(cultivation_plan_id: @plan.id)
    end
  end

  test 'progress gateway receives weather data filtered from start date' do
    schedule_gateway = StubScheduleGateway.new
    fertilize_gateway = StubFertilizeGateway.new
    progress_gateway = StubProgressGateway.new(progress_response)

    service = TaskScheduleGeneratorService.new(
      schedule_gateway: schedule_gateway,
      fertilize_gateway: fertilize_gateway,
      progress_gateway: progress_gateway
    )

    service.generate!(cultivation_plan_id: @plan.id)

    passed_weather_data = progress_gateway.received_payloads.last[:weather_data]
    refute_nil passed_weather_data, 'weather data should be passed to progress gateway'
    filtered_times = Array(passed_weather_data['data']).map { |entry| entry['time'] }
    assert filtered_times.all? { |time| Date.parse(time) >= @field_cultivation.start_date }, 'weather data should be filtered to start date or later'
  end

  test 'generate! ignores progress records before field cultivation start date' do
    early_progress_response = progress_response.merge(
      'progress_records' => [
        { 'date' => '2025-03-20T00:00:00', 'cumulative_gdd' => 0.0 },
        { 'date' => '2025-04-01T00:00:00', 'cumulative_gdd' => 0.0 },
        { 'date' => '2025-04-06T00:00:00', 'cumulative_gdd' => 165.0 }
      ]
    )

    progress_gateway = StubProgressGateway.new(early_progress_response)
    service = TaskScheduleGeneratorService.new(
      schedule_gateway: StubScheduleGateway.new,
      fertilize_gateway: StubFertilizeGateway.new,
      progress_gateway: progress_gateway
    )

    service.generate!(cultivation_plan_id: @plan.id)

    general_schedule = TaskSchedule.find_by!(cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'general')
    fertilizer_schedule = TaskSchedule.find_by!(cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'fertilizer')

    assert_equal Date.new(2025, 4, 1), general_schedule.task_schedule_items.minimum(:scheduled_date), 'general tasks should not be scheduled before the start date'
    assert_equal Date.new(2025, 4, 1), fertilizer_schedule.task_schedule_items.minimum(:scheduled_date), 'fertilizer tasks should not be scheduled before the start date'
  end

  test 'generate! raises error when gdd trigger is missing in blueprints' do
    progress_gateway = StubProgressGateway.new(progress_response)
    service = TaskScheduleGeneratorService.new(
      schedule_gateway: StubScheduleGateway.new,
      fertilize_gateway: StubFertilizeGateway.new,
      progress_gateway: progress_gateway
    )

    broken_blueprints = @crop.crop_task_schedule_blueprints.includes(:agricultural_task).ordered.to_a
    broken_blueprints.first.gdd_trigger = nil

    service.stub(:blueprints_for, ->(_crop, _cache) { broken_blueprints }) do
      assert_raises TaskScheduleGeneratorService::GddTriggerMissingError do
        service.generate!(cultivation_plan_id: @plan.id)
      end
    end
  end

  test 'tasks respect increasing gdd triggers and are not all on start date' do
    blueprint = CropTaskScheduleBlueprint.find_by!(crop: @crop, task_type: TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE)
    blueprint.update!(gdd_trigger: BigDecimal('200.0'))

    staggered_progress = progress_response.merge(
      'progress_records' => [
        { 'date' => '2025-04-01T00:00:00', 'cumulative_gdd' => 0.0 },
        { 'date' => '2025-04-03T00:00:00', 'cumulative_gdd' => 120.0 },
        { 'date' => '2025-04-10T00:00:00', 'cumulative_gdd' => 205.0 }
      ]
    )

    progress_gateway = StubProgressGateway.new(staggered_progress)
    service = TaskScheduleGeneratorService.new(
      schedule_gateway: StubScheduleGateway.new,
      fertilize_gateway: StubFertilizeGateway.new,
      progress_gateway: progress_gateway
    )

    service.generate!(cultivation_plan_id: @plan.id)

    fertilizer_schedule = TaskSchedule.find_by!(cultivation_plan: @plan, field_cultivation: @field_cultivation, category: 'fertilizer')
    dates = fertilizer_schedule.task_schedule_items.order(:scheduled_date).pluck(:scheduled_date)

    assert_equal Date.new(2025, 4, 1), dates.first
    assert dates.second > Date.new(2025, 4, 1), 'tasks with higher GDD thresholds must move to later dates'
  end

  private

  def mocked_weather_data
    {
      'location' => {
        'latitude' => 35.0,
        'longitude' => 135.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => [
        { 'time' => '2025-03-20T00:00:00', 'temperature_2m_mean' => 10.0 },
        { 'time' => '2025-03-25T00:00:00', 'temperature_2m_mean' => 12.0 },
        { 'time' => '2025-04-01T00:00:00', 'temperature_2m_mean' => 15.0 },
        { 'time' => '2025-04-05T00:00:00', 'temperature_2m_mean' => 18.0 },
        { 'time' => '2025-04-10T00:00:00', 'temperature_2m_mean' => 20.0 }
      ]
    }
  end

  def progress_response
    {
      'progress_records' => [
        { 'date' => '2025-04-01T00:00:00', 'cumulative_gdd' => 0.0 },
        { 'date' => '2025-04-04T00:00:00', 'cumulative_gdd' => 120.0 },
        { 'date' => '2025-04-06T00:00:00', 'cumulative_gdd' => 165.0 }
      ],
      'total_gdd' => 600.0
    }
  end
end

