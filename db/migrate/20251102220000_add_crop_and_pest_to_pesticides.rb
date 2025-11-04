# frozen_string_literal: true

class AddCropAndPestToPesticides < ActiveRecord::Migration[8.0]
  def change
    add_reference :pesticides, :crop, null: false, foreign_key: true
    add_reference :pesticides, :pest, null: false, foreign_key: true
    
    add_index :pesticides, [:crop_id, :pest_id, :pesticide_id], unique: true, name: 'index_pesticides_on_crop_pest_pesticide_id'
  end
end




