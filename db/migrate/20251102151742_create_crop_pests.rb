# frozen_string_literal: true

class CreateCropPests < ActiveRecord::Migration[8.0]
  def change
    create_table :crop_pests do |t|
      t.references :crop, null: false, foreign_key: true
      t.references :pest, null: false, foreign_key: true
      
      t.timestamps
    end
    
    add_index :crop_pests, [:crop_id, :pest_id], unique: true
  end
end
