class AddIsPredictedToWeatherData < ActiveRecord::Migration[8.0]
  def change
    add_column :weather_data, :is_predicted, :boolean
  end
end
