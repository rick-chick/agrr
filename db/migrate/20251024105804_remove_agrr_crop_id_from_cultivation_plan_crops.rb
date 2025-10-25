class RemoveAgrrCropIdFromCultivationPlanCrops < ActiveRecord::Migration[8.0]
  def change
    remove_column :cultivation_plan_crops, :agrr_crop_id, :string
  end
end
