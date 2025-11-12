class CreateCropTaskTemplates < ActiveRecord::Migration[7.1]
  def up
    create_table :crop_task_templates do |t|
      t.references :crop, null: false, foreign_key: true
      t.bigint :source_agricultural_task_id
      t.string :name, null: false
      t.text :description
      t.float :time_per_sqm
      t.string :weather_dependency
      t.text :required_tools
      t.string :skill_level
      t.string :task_type
      t.integer :task_type_id
      t.boolean :is_reference, null: false, default: false
      t.timestamps
    end

    add_index :crop_task_templates, [:crop_id, :name], unique: true
    add_index :crop_task_templates,
              [:crop_id, :source_agricultural_task_id],
              unique: true,
              name: "idx_crop_task_templates_on_crop_and_source"

  end

  def down
    drop_table :crop_task_templates
  end
end

