class AddWeatherDataStatusToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :weather_data_status, :string, default: 'pending', null: false
    add_column :farms, :weather_data_fetched_years, :integer, default: 0, null: false
    add_column :farms, :weather_data_total_years, :integer, default: 0, null: false
    add_column :farms, :weather_data_last_error, :text
    
    add_index :farms, :weather_data_status
  end
end
