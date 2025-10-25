class RemoveAgrrCropIdFromCrops < ActiveRecord::Migration[8.0]
  def change
    remove_column :crops, :agrr_crop_id, :string
  end
end
