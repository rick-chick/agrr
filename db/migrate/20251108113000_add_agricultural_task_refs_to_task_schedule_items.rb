# frozen_string_literal: true

class AddAgriculturalTaskRefsToTaskScheduleItems < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:task_schedule_items)

    unless column_exists?(:task_schedule_items, :agricultural_task_id)
      add_reference :task_schedule_items, :agricultural_task, foreign_key: true, index: true
    end

    unless column_exists?(:task_schedule_items, :source_agricultural_task_id)
      add_column :task_schedule_items, :source_agricultural_task_id, :bigint
      add_index :task_schedule_items, :source_agricultural_task_id
    end
  end

  def down
    return unless table_exists?(:task_schedule_items)

    if index_exists?(:task_schedule_items, :source_agricultural_task_id)
      remove_index :task_schedule_items, :source_agricultural_task_id
    end
    if column_exists?(:task_schedule_items, :source_agricultural_task_id)
      remove_column :task_schedule_items, :source_agricultural_task_id
    end

    if column_exists?(:task_schedule_items, :agricultural_task_id)
      remove_reference :task_schedule_items, :agricultural_task, foreign_key: true
    end
  end
end

