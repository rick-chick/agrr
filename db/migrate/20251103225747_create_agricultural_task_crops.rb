class CreateAgriculturalTaskCrops < ActiveRecord::Migration[8.0]
  def change
    create_table :agricultural_task_crops do |t|
      t.references :agricultural_task, null: false, foreign_key: true
      t.references :crop, null: false, foreign_key: true

      t.timestamps
    end

    add_index :agricultural_task_crops, [:agricultural_task_id, :crop_id], unique: true, name: 'index_agricultural_task_crops_on_task_and_crop'
  end
end
