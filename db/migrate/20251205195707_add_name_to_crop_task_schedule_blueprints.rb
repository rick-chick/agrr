class AddNameToCropTaskScheduleBlueprints < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:crop_task_schedule_blueprints, :name)
      add_column :crop_task_schedule_blueprints, :name, :string
    end
  end
end

