class CreateCropTaskScheduleBlueprints < ActiveRecord::Migration[8.0]
  def change
    create_table :crop_task_schedule_blueprints do |t|
      t.references :crop, null: false, foreign_key: true
      t.references :agricultural_task, foreign_key: true
      t.bigint :source_agricultural_task_id
      t.integer :stage_order, null: false
      t.string :stage_name
      t.decimal :gdd_trigger, precision: 10, scale: 2, null: false
      t.decimal :gdd_tolerance, precision: 10, scale: 2
      t.string :task_type, null: false
      t.string :source, null: false
      t.integer :priority, null: false
      t.decimal :amount, precision: 10, scale: 3
      t.string :amount_unit
      t.text :description
      t.string :weather_dependency
      t.decimal :time_per_sqm, precision: 8, scale: 2

      t.timestamps
    end

    add_index :crop_task_schedule_blueprints,
              [:crop_id, :stage_order, :agricultural_task_id],
              unique: true,
              where: 'agricultural_task_id IS NOT NULL'

    add_index :crop_task_schedule_blueprints,
              [:crop_id, :stage_order, :source_agricultural_task_id],
              unique: true,
              where: 'agricultural_task_id IS NULL AND source_agricultural_task_id IS NOT NULL',
              name: 'index_blueprints_on_crop_stage_and_source_task'
  end
end
