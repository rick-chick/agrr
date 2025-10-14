class AddMaxTemperatureToTemperatureRequirements < ActiveRecord::Migration[8.0]
  def change
    add_column :temperature_requirements, :max_temperature, :float
  end
end
