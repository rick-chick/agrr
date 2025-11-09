class AddStatusAndActualsToTaskScheduleItems < ActiveRecord::Migration[8.0]
  def change
    add_column :task_schedule_items, :status, :string, null: false, default: 'planned'
    add_column :task_schedule_items, :actual_date, :date
    add_column :task_schedule_items, :actual_notes, :text
    add_column :task_schedule_items, :rescheduled_at, :datetime
    add_column :task_schedule_items, :cancelled_at, :datetime
    add_column :task_schedule_items, :completed_at, :datetime
    add_index :task_schedule_items, :status
  end
end
