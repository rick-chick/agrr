# frozen_string_literal: true

class CreatePesticideUsageConstraints < ActiveRecord::Migration[8.0]
  def change
    create_table :pesticide_usage_constraints do |t|
      t.references :pesticide, null: false, foreign_key: true
      t.float :min_temperature
      t.float :max_temperature
      t.float :max_wind_speed_m_s
      t.integer :max_application_count
      t.integer :harvest_interval_days
      t.text :other_constraints
      
      t.timestamps
    end
  end
end








