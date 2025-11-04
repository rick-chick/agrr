# frozen_string_literal: true

class CreatePesticides < ActiveRecord::Migration[8.0]
  def change
    create_table :pesticides do |t|
      t.string :pesticide_id, null: false
      t.string :name, null: false
      t.string :active_ingredient
      t.text :description
      t.boolean :is_reference, default: false, null: false
      
      t.timestamps
    end
    
    add_index :pesticides, :pesticide_id, unique: true
    add_index :pesticides, :is_reference
  end
end




