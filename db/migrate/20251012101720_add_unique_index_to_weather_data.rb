class AddUniqueIndexToWeatherData < ActiveRecord::Migration[8.0]
  def change
    # weather_dataテーブルに複合ユニークインデックスを追加
    # 同じ場所(weather_location_id)の同じ日付(date)のデータは1つだけ存在すべき
    add_index :weather_data, [:weather_location_id, :date], unique: true, 
              name: 'index_weather_data_on_location_and_date'
  end
end
