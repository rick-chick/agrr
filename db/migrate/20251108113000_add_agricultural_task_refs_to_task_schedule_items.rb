# frozen_string_literal: true

class AddAgriculturalTaskRefsToTaskScheduleItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :task_schedule_items, :agricultural_task, foreign_key: true, index: true
    add_column :task_schedule_items, :source_agricultural_task_id, :bigint
    add_index :task_schedule_items, :source_agricultural_task_id
  end
end

