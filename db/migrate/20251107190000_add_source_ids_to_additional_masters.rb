class AddSourceIdsToAdditionalMasters < ActiveRecord::Migration[8.0]
  def change
    add_column :fertilizes, :source_fertilize_id, :integer
    add_index :fertilizes, [:user_id, :source_fertilize_id], unique: true, where: "source_fertilize_id IS NOT NULL"

    add_column :pests, :source_pest_id, :integer
    add_index :pests, [:user_id, :source_pest_id], unique: true, where: "source_pest_id IS NOT NULL"

    add_column :pesticides, :source_pesticide_id, :integer
    add_index :pesticides, [:user_id, :source_pesticide_id], unique: true, where: "source_pesticide_id IS NOT NULL"

    add_column :agricultural_tasks, :source_agricultural_task_id, :integer
    add_index :agricultural_tasks, [:user_id, :source_agricultural_task_id], unique: true, where: "source_agricultural_task_id IS NOT NULL"
  end
end

