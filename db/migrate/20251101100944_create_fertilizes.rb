# frozen_string_literal: true

class CreateFertilizes < ActiveRecord::Migration[8.0]
  def change
    create_table :fertilizes do |t|
      t.string :name, null: false
      t.float :n
      t.float :p
      t.float :k
      t.text :description
      t.text :usage
      t.string :application_rate
      t.boolean :is_reference, default: true, null: false
      
      t.timestamps
    end
    
    # nameは一意制約
    add_index :fertilizes, :name, unique: true
  end
end

