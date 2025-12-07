require 'test_helper'

class TaskScheduleItemTest < ActiveSupport::TestCase
  setup do
    @schedule = create(:task_schedule)
  end

  test 'agrr sourced item requires gdd trigger' do
    item = TaskScheduleItem.new(
      task_schedule: @schedule,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      name: '播種',
      source: 'agrr_schedule',
      gdd_trigger: nil
    )

    assert item.invalid?
    assert_includes item.errors[:gdd_trigger], I18n.t('activerecord.errors.models.task_schedule_item.attributes.gdd_trigger.agrr_required')
  end

  test 'non agrr source allows nil gdd trigger' do
    item = TaskScheduleItem.new(
      task_schedule: @schedule,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      name: '手動調整',
      source: 'manual_override',
      gdd_trigger: nil
    )

    assert item.valid?
  end
end

