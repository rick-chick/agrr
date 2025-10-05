# frozen_string_literal: true

class CreateFields < ActiveRecord::Migration[8.0]
  def change
    create_table :fields do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8

      t.timestamps
    end
    
    add_index :fields, [:user_id, :name], unique: true
  end
end
