# frozen_string_literal: true

class CreatePestControlMethods < ActiveRecord::Migration[8.0]
  def change
    create_table :pest_control_methods do |t|
      t.references :pest, null: false, foreign_key: true
      t.string :method_type, null: false
      t.string :method_name, null: false
      t.text :description
      t.string :timing_hint
      
      t.timestamps
    end
    
    add_index :pest_control_methods, :method_type
  end
end
