# frozen_string_literal: true

class CreatePestTemperatureProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :pest_temperature_profiles do |t|
      t.references :pest, null: false, foreign_key: true
      t.float :base_temperature
      t.float :max_temperature
      
      t.timestamps
    end
  end
end
