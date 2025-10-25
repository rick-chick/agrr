class AddCropIdToCultivationPlanCrops < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plan_crops, :crop_id, :integer
    add_foreign_key :cultivation_plan_crops, :crops
    add_index :cultivation_plan_crops, :crop_id
  end
end
