# frozen_string_literal: true

class AddPredictedWeatherDataToWeatherLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :weather_locations, :predicted_weather_data, :text
  end
end

