class AddPredictedWeatherDataToCultivationPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :cultivation_plans, :predicted_weather_data, :text
  end
end
