# frozen_string_literal: true

require 'test_helper'

class CropTaskScheduleBlueprintCreateServiceTest < ActiveSupport::TestCase
  class StubScheduleGateway
    def initialize(response)
      @response = response
    end

    def generate(*_args)
      @response
    end
  end

  class StubFertilizeGateway
    def initialize(response)
      @response = response
    end

    def plan(*_args)
      @response
    end
  end

  setup do
    @crop = create(:crop, :with_stages, name: 'トマト', variety: '一般')
    @soil_task = create(:agricultural_task, :soil_preparation)
    @soil_template = create(
      :crop_task_template,
      crop: @crop,
      agricultural_task: @soil_task,
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

    @schedule_response = {
      'task_schedules' => [
        {
          'task_id' => @soil_task.id.to_s,
          'stage_name' => '定植前整備',
          'stage_order' => 1,
          'gdd_trigger' => 0,
          'gdd_tolerance' => 5,
          'priority' => 1,
          'description' => '土壌準備',
          'weather_dependency' => 'low',
          'time_per_sqm' => '0.2'
        }
      ]
    }

    @fertilizer_task = create(:agricultural_task, name: '基肥')
    @fertilize_response = {
      'schedule' => [
        {
          'task_id' => @fertilizer_task.id.to_s,
          'stage_name' => '定植前',
          'stage_order' => 0,
          'gdd_trigger' => 0,
          'gdd_tolerance' => 5,
          'priority' => 1,
          'amount_g_per_m2' => 3.5,
          'weather_dependency' => 'medium'
        }
      ]
    }
  end

  test 'regenerate! stores crop task schedule blueprints' do
    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(@schedule_response),
      fertilize_gateway: StubFertilizeGateway.new(@fertilize_response)
    )

    assert_difference -> { CropTaskScheduleBlueprint.count }, 2 do
      service.regenerate!(crop: @crop)
    end

    @crop.reload
    general_blueprint = @crop.crop_task_schedule_blueprints.find_by!(agricultural_task: @soil_task)
    assert_equal BigDecimal('0'), general_blueprint.gdd_trigger
    assert_equal 'agrr_schedule', general_blueprint.source

    fertilizer_blueprint = @crop.crop_task_schedule_blueprints.find_by(task_type: TaskScheduleItem::BASAL_FERTILIZATION_TYPE)
    assert_not_nil fertilizer_blueprint.agricultural_task_id
    assert_equal BigDecimal('3.5'), fertilizer_blueprint.amount
  end

  test 'regenerate! replaces existing blueprints and updates gdd triggers' do
    existing_blueprint = create(
      :crop_task_schedule_blueprint,
      crop: @crop,
      agricultural_task: @soil_task,
      stage_order: 1,
      priority: 1,
      gdd_trigger: BigDecimal('75.0'),
      gdd_tolerance: BigDecimal('5.0'),
      source: 'agrr_schedule'
    )

    # preload association similarly to controller behaviour
    @crop.crop_task_schedule_blueprints.to_a

    updated_schedule = @schedule_response.deep_dup
    updated_schedule['task_schedules'][0]['gdd_trigger'] = 125

    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(updated_schedule),
      fertilize_gateway: StubFertilizeGateway.new(@fertilize_response)
    )

    service.regenerate!(crop: @crop)

    @crop.reload
    new_blueprint = @crop.crop_task_schedule_blueprints.find_by!(agricultural_task: @soil_task)
    assert_equal BigDecimal('125'), new_blueprint.gdd_trigger
    refute_equal existing_blueprint.id, new_blueprint.id
  end

  test 'regenerate! resets preload cache so subsequent reads reflect new values' do
    create(
      :crop_task_schedule_blueprint,
      crop: @crop,
      agricultural_task: @soil_task,
      stage_order: 1,
      priority: 1,
      gdd_trigger: BigDecimal('60.0'),
      source: 'agrr_schedule'
    )

    # 事前に関連を読み込んでキャッシュさせる
    @crop.crop_task_schedule_blueprints.load

    updated_schedule = @schedule_response.deep_dup
    updated_schedule['task_schedules'][0]['gdd_trigger'] = 180

    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(updated_schedule),
      fertilize_gateway: StubFertilizeGateway.new(@fertilize_response)
    )

    service.regenerate!(crop: @crop)

    # reloadせずに新しい値が参照できること
    current_blueprints = @crop.crop_task_schedule_blueprints
    assert_equal 2, current_blueprints.size
    regenerated = current_blueprints.find { |bp| bp.agricultural_task_id == @soil_task.id }
    assert_equal BigDecimal('180'), regenerated.gdd_trigger
  end

  test 'raises error when crop has no agricultural tasks' do
    crop_without_tasks = create(:crop, :with_stages, name: 'ナス', variety: '一般')

    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(@schedule_response),
      fertilize_gateway: StubFertilizeGateway.new(@fertilize_response)
    )

    assert_raises CropTaskScheduleBlueprintCreateService::MissingCropTaskTemplatesError do
      service.regenerate!(crop: crop_without_tasks)
    end
  end

  test 'raises error when generator returns no blueprints' do
    empty_schedule = { 'task_schedules' => [] }
    empty_fertilize = { 'schedule' => [] }

    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(empty_schedule),
      fertilize_gateway: StubFertilizeGateway.new(empty_fertilize)
    )

    assert_raises CropTaskScheduleBlueprintCreateService::GenerationFailedError do
      service.regenerate!(crop: @crop)
    end
  end

  test 'persists decimal attributes from strings without truncation' do
    precise_schedule = {
      'task_schedules' => [
        {
          'task_id' => @soil_task.id.to_s,
          'stage_name' => '整枝作業',
          'stage_order' => 2,
          'gdd_trigger' => '175.25',
          'gdd_tolerance' => '12.5',
          'priority' => 2,
          'description' => '枝を整える',
          'weather_dependency' => 'medium',
          'time_per_sqm' => '0.45'
        }
      ]
    }
    precise_fertilizer_task = create(:agricultural_task, name: '追肥2')
    precise_fertilize = {
      'schedule' => [
        {
          'task_id' => precise_fertilizer_task.id.to_s,
          'stage_name' => '追肥2',
          'stage_order' => 3,
          'gdd_trigger' => '210.75',
          'gdd_tolerance' => '8.25',
          'priority' => 3,
          'amount_g_per_m2' => '4.25',
          'weather_dependency' => 'high',
          'time_per_sqm' => '0.33'
        }
      ]
    }

    service = CropTaskScheduleBlueprintCreateService.new(
      schedule_gateway: StubScheduleGateway.new(precise_schedule),
      fertilize_gateway: StubFertilizeGateway.new(precise_fertilize)
    )

    service.regenerate!(crop: @crop)

    @crop.reload
    precise_blueprint = @crop.crop_task_schedule_blueprints.find_by!(stage_order: 2)
    assert_equal BigDecimal('175.25'), precise_blueprint.gdd_trigger
    assert_equal BigDecimal('12.5'), precise_blueprint.gdd_tolerance
    assert_equal BigDecimal('0.45'), precise_blueprint.time_per_sqm

    fertilizer_blueprint = @crop.crop_task_schedule_blueprints.find_by!(task_type: TaskScheduleItem::BASAL_FERTILIZATION_TYPE)
    assert_equal BigDecimal('210.75'), fertilizer_blueprint.gdd_trigger
    assert_equal BigDecimal('8.25'), fertilizer_blueprint.gdd_tolerance
    assert_equal BigDecimal('4.25'), fertilizer_blueprint.amount
    assert_equal BigDecimal('0.33'), fertilizer_blueprint.time_per_sqm
  end
end
