class AddAgrrCropIdToCrops < ActiveRecord::Migration[8.0]
  def change
    add_column :crops, :agrr_crop_id, :string
    add_index :crops, :agrr_crop_id
  end
end
