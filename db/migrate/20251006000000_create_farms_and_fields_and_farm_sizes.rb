# frozen_string_literal: true

class CreateFarmsAndFieldsAndFarmSizes < ActiveRecord::Migration[8.0]
  def change
    # Farms table
    create_table :farms do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8

      t.timestamps
    end
    
    add_index :farms, [:user_id, :name], unique: true
    
    # Fields table
    create_table :fields do |t|
      t.references :farm, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    
    add_index :fields, [:farm_id, :name], unique: true
    add_index :fields, [:user_id, :name], unique: true
    
    # FarmSizes table
    create_table :farm_sizes do |t|
      t.string :name, null: false
      t.integer :area_sqm, null: false
      t.integer :display_order, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :farm_sizes, :display_order
    add_index :farm_sizes, :active
  end
end

