require 'test_helper'

class CropTaskScheduleBlueprintGeneratorTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop, :with_stages, name: 'トマト', variety: '一般')
    @soil_task = create(:agricultural_task, :soil_preparation)
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
  end

  test 'builds blueprint attributes from agrr schedule responses' do
    generator = CropTaskScheduleBlueprintGenerator.new(crop: @crop)

    schedule_response = {
      'task_schedules' => [
        {
          'task_id' => @soil_task.id.to_s,
          'stage_name' => '定植前整備',
          'stage_order' => 1,
          'gdd_trigger' => 0,
          'gdd_tolerance' => 10,
          'priority' => 1,
          'description' => '圃場を整える',
          'weather_dependency' => 'low',
          'time_per_sqm' => '0.2'
        }
      ]
    }
    fertilize_response = {
      'schedule' => [
        {
          'task_id' => '1200',
          'stage_name' => '定植前',
          'stage_order' => 0,
          'gdd_trigger' => 0,
          'gdd_tolerance' => 5,
          'priority' => 1,
          'amount_g_per_m2' => 3.5,
          'weather_dependency' => 'medium'
        },
        {
          'task_id' => '1201',
          'stage_name' => '追肥',
          'stage_order' => 2,
          'gdd_trigger' => 150,
          'gdd_tolerance' => 12,
          'priority' => 2,
          'amount_g_per_m2' => 4.0,
          'weather_dependency' => 'high'
        }
      ]
    }

    blueprints = generator.build_from_responses(
      schedule_response: schedule_response,
      fertilize_response: fertilize_response
    )

    assert_equal 3, blueprints.length

    general_blueprint = blueprints.find { |attrs| attrs[:task_type] == TaskScheduleItem::FIELD_WORK_TYPE }
    assert_equal @crop.id, general_blueprint[:crop_id]
    assert_equal @soil_task.id, general_blueprint[:agricultural_task_id]
    assert_equal BigDecimal('0'), general_blueprint[:gdd_trigger]
    assert_equal BigDecimal('10'), general_blueprint[:gdd_tolerance]
    assert_equal '定植前整備', general_blueprint[:stage_name]
    assert_equal 'agrr_schedule', general_blueprint[:source]
    assert_equal BigDecimal('0.2'), general_blueprint[:time_per_sqm]

    basal_blueprint = blueprints.find { |attrs| attrs[:task_type] == TaskScheduleItem::BASAL_FERTILIZATION_TYPE }
    assert_nil basal_blueprint[:agricultural_task_id]
    assert_equal 1200, basal_blueprint[:source_agricultural_task_id]
    assert_equal BigDecimal('3.5'), basal_blueprint[:amount]
    assert_equal 'g/m2', basal_blueprint[:amount_unit]
    assert_equal 'agrr_fertilize_plan', basal_blueprint[:source]

    topdress_blueprint = blueprints.find { |attrs| attrs[:task_type] == TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE }
    assert_equal 1201, topdress_blueprint[:source_agricultural_task_id]
    assert_equal BigDecimal('150'), topdress_blueprint[:gdd_trigger]
    assert_equal 2, topdress_blueprint[:priority]
  end
end
