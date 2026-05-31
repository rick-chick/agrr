class AddSourceTaskToCropTaskScheduleBlueprints < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:crop_task_schedule_blueprints, :source_agricultural_task_id)
      add_column :crop_task_schedule_blueprints, :source_agricultural_task_id, :bigint
    end

    unless index_exists?(:crop_task_schedule_blueprints,
                        %i[crop_id stage_order source_agricultural_task_id],
                        name: 'index_blueprints_on_crop_stage_and_source_task')
      add_index :crop_task_schedule_blueprints,
                %i[crop_id stage_order source_agricultural_task_id],
                unique: true,
                where: 'agricultural_task_id IS NULL AND source_agricultural_task_id IS NOT NULL',
                name: 'index_blueprints_on_crop_stage_and_source_task'
    end
  end
end
