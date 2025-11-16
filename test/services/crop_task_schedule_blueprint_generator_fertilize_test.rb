require 'test_helper'

class CropTaskScheduleBlueprintGeneratorFertilizeTest < ActiveSupport::TestCase
  def setup
    @crop = create(:crop, :with_stages, name: 'トマト', variety: '一般')
  end

  test 'first fertilize entry becomes 基肥 and second becomes 追肥' do
    fertilize_response = {
      'schedule' => [
        { 'task_id' => '1', 'stage_order' => 0, 'stage_name' => '任意A', 'gdd_trigger' => 0, 'gdd_tolerance' => 0 },
        { 'task_id' => '2', 'stage_order' => 1, 'stage_name' => '任意B', 'gdd_trigger' => 0, 'gdd_tolerance' => 0 }
      ]
    }

    generator = CropTaskScheduleBlueprintGenerator.new(crop: @crop)
    blueprints = generator.build_from_responses(schedule_response: { 'task_schedules' => [] }, fertilize_response: fertilize_response)
    fert_blueprints = blueprints.select { |b| b[:source] == 'agrr_fertilize_plan' }

    assert_equal 2, fert_blueprints.size
    first, second = fert_blueprints

    assert_equal '基肥', first[:stage_name]
    assert_equal '基肥', first[:description]
    assert_equal TaskScheduleItem::BASAL_FERTILIZATION_TYPE, first[:task_type]

    assert_equal '追肥', second[:stage_name]
    assert_equal '追肥', second[:description]
    assert_equal TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE, second[:task_type]
  end
end


