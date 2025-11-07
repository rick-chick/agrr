class AddTaskTypeToAgriculturalTasks < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:agricultural_tasks, :task_type)
      add_column :agricultural_tasks, :task_type, :string
      add_index :agricultural_tasks, :task_type
    end

    unless column_exists?(:agricultural_tasks, :task_type_id)
      add_column :agricultural_tasks, :task_type_id, :integer
      add_index :agricultural_tasks, :task_type_id
    end
  end
end


