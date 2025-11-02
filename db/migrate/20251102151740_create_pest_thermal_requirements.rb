# frozen_string_literal: true

class CreatePestThermalRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :pest_thermal_requirements do |t|
      t.references :pest, null: false, foreign_key: true
      t.float :required_gdd
      t.float :first_generation_gdd
      
      t.timestamps
    end
  end
end
