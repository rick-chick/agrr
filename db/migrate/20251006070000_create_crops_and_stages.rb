# frozen_string_literal: true

class CreateCropsAndStages < ActiveRecord::Migration[7.1]
  def change
    create_table :crops do |t|
      t.references :user, null: true, foreign_key: true
      t.string :name, null: false
      t.string :variety
      t.boolean :is_reference, null: false, default: false
      t.timestamps
    end

    create_table :crop_stages do |t|
      t.references :crop, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :order, null: false
      t.timestamps
    end
    add_index :crop_stages, [:crop_id, :order], unique: true

    create_table :temperature_requirements do |t|
      t.references :crop_stage, null: false, foreign_key: true
      t.float :base_temperature
      t.float :optimal_min
      t.float :optimal_max
      t.float :low_stress_threshold
      t.float :high_stress_threshold
      t.float :frost_threshold
      t.float :sterility_risk_threshold
      t.timestamps
    end

    create_table :sunshine_requirements do |t|
      t.references :crop_stage, null: false, foreign_key: true
      t.float :minimum_sunshine_hours
      t.float :target_sunshine_hours
      t.timestamps
    end

    create_table :thermal_requirements do |t|
      t.references :crop_stage, null: false, foreign_key: true
      t.float :required_gdd
      t.timestamps
    end
  end
end


