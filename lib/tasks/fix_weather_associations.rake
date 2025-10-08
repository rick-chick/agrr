# frozen_string_literal: true

namespace :weather do
  desc "既存の農場にWeatherLocationを関連付ける"
  task fix_associations: :environment do
    puts "=" * 70
    puts "既存の農場にWeatherLocationを関連付けます"
    puts "=" * 70
    
    Farm.where(weather_location_id: nil).each do |farm|
      next unless farm.latitude.present? && farm.longitude.present?
      
      # 座標から WeatherLocation を検索
      # 天気APIが返す座標は農場の座標と微妙に異なる可能性があるため、許容範囲を広げる
      tolerance = 0.01  # 約1.1km
      weather_location = WeatherLocation.where(
        'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
        farm.latitude, tolerance,
        farm.longitude, tolerance
      ).order(
        Arel.sql("(ABS(latitude - #{farm.latitude.to_f}) + ABS(longitude - #{farm.longitude.to_f}))")
      ).first
      
      if weather_location
        farm.update_column(:weather_location_id, weather_location.id)
        data_count = weather_location.weather_data.count
        puts "✅ Farm##{farm.id} '#{farm.name}' -> WeatherLocation##{weather_location.id} (データ数: #{data_count})"
      else
        puts "⚠️  Farm##{farm.id} '#{farm.name}' - WeatherLocationが見つかりません"
      end
    end
    
    puts "=" * 70
    puts "完了"
    puts "=" * 70
  end
end

