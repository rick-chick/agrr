class AddPredictedWeatherDataToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :predicted_weather_data, :text
  end
end
