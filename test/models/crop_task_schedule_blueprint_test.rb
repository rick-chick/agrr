require 'test_helper'

class CropTaskScheduleBlueprintTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop, :with_stages)
    @agricultural_task = create(:agricultural_task)
  end

  test 'valid blueprint with agricultural task' do
    blueprint = build(:crop_task_schedule_blueprint, crop: @crop, agricultural_task: @agricultural_task)

    assert blueprint.valid?
  end

  test 'requires source_agricultural_task_id when agricultural_task is missing' do
    blueprint = build(:crop_task_schedule_blueprint, :without_agricultural_task, crop: @crop, source_agricultural_task_id: nil)

    refute blueprint.valid?
    assert_includes blueprint.errors[:source_agricultural_task_id], 'must be present when agricultural_task is missing'
  end

  test 'enforces uniqueness by crop, stage_order, agricultural_task combination' do
    create(:crop_task_schedule_blueprint, crop: @crop, agricultural_task: @agricultural_task, stage_order: 2)
    duplicate = build(:crop_task_schedule_blueprint, crop: @crop, agricultural_task: @agricultural_task, stage_order: 2)

    refute duplicate.valid?
    assert_includes duplicate.errors.details[:agricultural_task_id].map { |detail| detail[:error] }, :taken
  end

  test 'enforces uniqueness by crop, stage_order, source_agricultural_task_id when agricultural_task missing' do
    create(:crop_task_schedule_blueprint, :without_agricultural_task, crop: @crop, stage_order: 3, source_agricultural_task_id: 12_345)
    duplicate = build(:crop_task_schedule_blueprint, :without_agricultural_task, crop: @crop, stage_order: 3, source_agricultural_task_id: 12_345)

    refute duplicate.valid?
    assert_includes duplicate.errors.details[:source_agricultural_task_id].map { |detail| detail[:error] }, :taken
  end

  test 'requires essential attributes' do
    blueprint = build(:crop_task_schedule_blueprint,
                      crop: nil,
                      agricultural_task: @agricultural_task,
                      stage_order: nil,
                      gdd_trigger: nil,
                      task_type: nil,
                      source: nil,
                      priority: nil)

    refute blueprint.valid?
    assert_equal %i[crop stage_order gdd_trigger task_type source priority].sort,
                 blueprint.errors.attribute_names.sort
  end
end
