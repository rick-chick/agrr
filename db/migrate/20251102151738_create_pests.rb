# frozen_string_literal: true

class CreatePests < ActiveRecord::Migration[8.0]
  def change
    create_table :pests do |t|
      t.string :pest_id, null: false
      t.string :name, null: false
      t.string :name_scientific
      t.string :family
      t.string :order
      t.text :description
      t.string :occurrence_season
      t.boolean :is_reference, default: false, null: false
      
      t.timestamps
    end
    
    add_index :pests, :pest_id, unique: true
    add_index :pests, :is_reference
  end
end
