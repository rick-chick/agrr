class CreateWeatherData < ActiveRecord::Migration[8.0]
  def change
    create_table :weather_data do |t|
      t.references :weather_location, null: false, foreign_key: true
      t.date :date
      t.decimal :temperature_max
      t.decimal :temperature_min
      t.decimal :temperature_mean
      t.decimal :precipitation
      t.decimal :sunshine_hours
      t.decimal :wind_speed
      t.integer :weather_code

      t.timestamps
    end
  end
end
