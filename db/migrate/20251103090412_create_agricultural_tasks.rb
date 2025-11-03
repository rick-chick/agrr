class CreateAgriculturalTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :agricultural_tasks do |t|
      t.string :name, null: false
      t.text :description
      t.float :time_per_sqm
      t.string :weather_dependency
      t.text :required_tools # JSON配列として保存
      t.string :skill_level
      t.boolean :is_reference, default: true, null: false
      t.integer :user_id

      t.timestamps
    end

    add_index :agricultural_tasks, :user_id
    add_index :agricultural_tasks, :is_reference
    add_index :agricultural_tasks, [:user_id, :name], unique: true, where: "is_reference = false"
    add_index :agricultural_tasks, :name, where: "is_reference = true"
  end
end
