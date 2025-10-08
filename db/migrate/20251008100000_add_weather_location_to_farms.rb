# frozen_string_literal: true

class AddWeatherLocationToFarms < ActiveRecord::Migration[8.0]
  def change
    add_reference :farms, :weather_location, foreign_key: true, null: true, index: true
  end
end

