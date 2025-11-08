class CreateTaskSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :task_schedules do |t|
      t.references :cultivation_plan, null: false, foreign_key: true
      t.references :field_cultivation, foreign_key: true
      t.string :category, null: false
      t.string :status, null: false, default: 'active'
      t.string :source, null: false, default: 'agrr'
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :task_schedules,
              [:cultivation_plan_id, :field_cultivation_id, :category],
              unique: true,
              name: 'index_task_schedules_unique_scope'

    create_table :task_schedule_items do |t|
      t.references :task_schedule, null: false, foreign_key: true
      t.string :task_type, null: false
      t.string :name, null: false
      t.text :description
      t.string :stage_name
      t.integer :stage_order
      t.decimal :gdd_trigger, precision: 10, scale: 2
      t.decimal :gdd_tolerance, precision: 10, scale: 2
      t.date :scheduled_date
      t.integer :priority
      t.string :source, null: false
      t.string :weather_dependency
      t.decimal :time_per_sqm, precision: 8, scale: 2
      t.decimal :amount, precision: 10, scale: 3
      t.string :amount_unit

      t.timestamps
    end

    add_index :task_schedule_items, :scheduled_date
    add_index :task_schedule_items, [:task_schedule_id, :scheduled_date], name: 'index_task_schedule_items_on_schedule_and_date'
  end
end

