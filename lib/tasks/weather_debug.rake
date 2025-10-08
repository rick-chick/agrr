# frozen_string_literal: true

namespace :weather do
  desc "Debug weather data for a farm"
  task :debug, [:farm_id] => :environment do |t, args|
    unless args[:farm_id]
      puts "Usage: rails weather:debug[FARM_ID]"
      exit 1
    end

    farm = Farm.find(args[:farm_id])
    puts "=" * 60
    puts "農場情報"
    puts "=" * 60
    puts "ID: #{farm.id}"
    puts "名前: #{farm.name}"
    puts "緯度: #{farm.latitude}"
    puts "経度: #{farm.longitude}"
    puts "天気データステータス: #{farm.weather_data_status}"
    puts "取得済みブロック: #{farm.weather_data_fetched_years}/#{farm.weather_data_total_years}"
    puts

    puts "=" * 60
    puts "WeatherLocation検索"
    puts "=" * 60
    
    # 完全一致を試す
    exact_match = WeatherLocation.find_by(
      latitude: farm.latitude,
      longitude: farm.longitude
    )
    
    if exact_match
      puts "✅ 完全一致: 見つかりました (ID: #{exact_match.id})"
    else
      puts "❌ 完全一致: 見つかりませんでした"
    end
    
    # 近似マッチを試す
    tolerance = 0.0001
    nearby = WeatherLocation.where(
      'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
      farm.latitude, tolerance,
      farm.longitude, tolerance
    )
    
    puts "近似マッチ (±#{tolerance}度): #{nearby.count}件"
    nearby.each do |loc|
      puts "  - ID: #{loc.id}, 緯度: #{loc.latitude}, 経度: #{loc.longitude}"
      lat_diff = (loc.latitude.to_f - farm.latitude.to_f).abs
      lon_diff = (loc.longitude.to_f - farm.longitude.to_f).abs
      puts "    緯度差: #{lat_diff}, 経度差: #{lon_diff}"
    end
    puts

    # 全てのWeatherLocationを表示
    all_locations = WeatherLocation.all
    puts "=" * 60
    puts "全WeatherLocation (#{all_locations.count}件)"
    puts "=" * 60
    all_locations.each do |loc|
      data_count = loc.weather_data.count
      puts "ID: #{loc.id}, 緯度: #{loc.latitude}, 経度: #{loc.longitude}, データ数: #{data_count}"
    end
    puts

    # 天気データ確認
    location = exact_match || nearby.first
    if location
      puts "=" * 60
      puts "天気データ (WeatherLocation ID: #{location.id})"
      puts "=" * 60
      total_count = location.weather_data.count
      puts "総データ数: #{total_count}"
      
      if total_count > 0
        earliest = location.weather_data.order(:date).first
        latest = location.weather_data.order(:date).last
        puts "期間: #{earliest.date} ~ #{latest.date}"
        
        # 直近のデータを表示
        recent = location.weather_data.order(date: :desc).limit(5)
        puts "\n直近5件のデータ:"
        recent.each do |data|
          puts "  #{data.date}: 最高#{data.temperature_max}℃, 最低#{data.temperature_min}℃, 平均#{data.temperature_mean}℃"
        end
      else
        puts "⚠️  天気データがありません"
      end
    else
      puts "=" * 60
      puts "⚠️  対応するWeatherLocationが見つかりません"
      puts "=" * 60
    end
  end

  desc "List all farms and their weather data status"
  task :list => :environment do
    puts "=" * 60
    puts "全農場の天気データステータス"
    puts "=" * 60
    
    Farm.all.each do |farm|
      puts "\nID: #{farm.id} - #{farm.name}"
      puts "  位置: (#{farm.latitude}, #{farm.longitude})"
      puts "  ステータス: #{farm.weather_data_status}"
      puts "  進捗: #{farm.weather_data_fetched_years}/#{farm.weather_data_total_years}"
      
      # WeatherLocationを探す
      # 直接の関連を優先
      location = farm.weather_location
      
      # なければ座標検索（許容範囲: 0.01度 ≈ 1.1km）
      if location.nil?
        tolerance = 0.01
        location = WeatherLocation.where(
          'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
          farm.latitude, tolerance,
          farm.longitude, tolerance
        ).order(
          Arel.sql("(ABS(latitude - #{farm.latitude.to_f}) + ABS(longitude - #{farm.longitude.to_f}))")
        ).first
      end
      
      if location
        data_count = location.weather_data.count
        puts "  ✅ WeatherLocation見つかりました (ID: #{location.id}, データ数: #{data_count})"
      else
        puts "  ❌ WeatherLocationが見つかりません"
      end
    end
  end
end

