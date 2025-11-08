require 'test_helper'

class TaskScheduleGeneratorServiceTest < ActiveSupport::TestCase
  class StubScheduleGateway
    attr_reader :received_payloads

    def initialize(response)
      @response = response
      @received_payloads = []
    end

    def generate(crop_name:, variety:, stage_requirements:, agricultural_tasks:)
      @received_payloads << {
        crop_name: crop_name,
        variety: variety,
        stage_requirements: stage_requirements,
        agricultural_tasks: agricultural_tasks
      }
      @response
    end
  end

  class StubFertilizeGateway
    attr_reader :received_payloads

    def initialize(response)
      @response = response
      @received_payloads = []
    end

    def plan(crop:, use_harvest_start:)
      @received_payloads << { crop: crop, use_harvest_start: use_harvest_start }
      @response
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
    AgriculturalTaskCrop.create!(agricultural_task: @soil_task, crop: @crop)
    AgriculturalTaskCrop.create!(agricultural_task: @planting_task, crop: @crop)

    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop, name: @crop.name, variety: @crop.variety)
    @plan_field = create(:cultivation_plan_field, cultivation_plan: @plan)
    @field_cultivation = create(:field_cultivation,
                                cultivation_plan: @plan,
                                cultivation_plan_field: @plan_field,
                                cultivation_plan_crop: @plan_crop,
                                area: 120.0,
                                start_date: Date.new(2025, 4, 1),
                                completion_date: Date.new(2025, 8, 1))
  end

  test 'generate! creates schedules and items with mapped dates' do
    schedule_gateway = StubScheduleGateway.new(schedule_response)
    fertilize_gateway = StubFertilizeGateway.new(fertilize_response)
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

    general_item = general_schedule.task_schedule_items.find_by!(task_type: 'field_work')
    assert_equal Date.new(2025, 4, 1), general_item.scheduled_date
    assert_equal BigDecimal('0.0'), general_item.gdd_trigger

    basal_item = fertilizer_schedule.task_schedule_items.order(:scheduled_date).first
    assert_equal 'basal_fertilization', basal_item.task_type
    assert_equal Date.new(2025, 4, 1), basal_item.scheduled_date

    topdress_items = fertilizer_schedule.task_schedule_items.where(task_type: 'topdress_fertilization')
    assert_equal 1, topdress_items.count
    assert_equal Date.new(2025, 4, 6), topdress_items.first.scheduled_date
    assert_equal BigDecimal('160.0'), topdress_items.first.gdd_trigger
  end

  test 'generate! raises error when progress has no records' do
    schedule_gateway = StubScheduleGateway.new(schedule_response)
    fertilize_gateway = StubFertilizeGateway.new(fertilize_response)
    progress_gateway = StubProgressGateway.new(progress_response.merge('progress_records' => []))

    service = TaskScheduleGeneratorService.new(
      schedule_gateway: schedule_gateway,
      fertilize_gateway: fertilize_gateway,
      progress_gateway: progress_gateway
    )

    assert_raises TaskScheduleGeneratorService::ProgressDataMissingError do
      service.generate!(cultivation_plan_id: @plan.id)
    end
  end

  private

  def mocked_weather_data
    {
      'location' => {
        'latitude' => 35.0,
        'longitude' => 135.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => []
    }
  end

  def schedule_response
    {
      'task_schedules' => [
        {
          'task_id' => 'soil_preparation',
          'stage_order' => 1,
          'gdd_trigger' => 0.0,
          'gdd_tolerance' => 10.0,
          'priority' => 1,
          'description' => '土壌準備',
          'weather_dependency' => 'low'
        }
      ]
    }
  end

  def fertilize_response
    {
      'schedule' => [
        {
          'task_id' => 'fertilize',
          'stage_name' => '定植前',
          'stage_order' => 0,
          'gdd_trigger' => 0.0,
          'amount_g_per_m2' => 3.14
        },
        {
          'task_id' => 'fertilize',
          'stage_name' => '生育期',
          'stage_order' => 2,
          'gdd_trigger' => 160.0,
          'amount_g_per_m2' => 4.0
        }
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

