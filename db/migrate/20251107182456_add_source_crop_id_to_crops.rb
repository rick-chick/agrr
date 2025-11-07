# frozen_string_literal: true

class AddSourceCropIdToCrops < ActiveRecord::Migration[8.0]
  def change
    add_column :crops, :source_crop_id, :integer
    add_index :crops, [:user_id, :source_crop_id], unique: true, where: "source_crop_id IS NOT NULL"
  end
end

