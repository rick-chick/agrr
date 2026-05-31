class CreateWeatherLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :weather_locations do |t|
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :elevation
      t.string :timezone

      t.timestamps
    end
  end
end
