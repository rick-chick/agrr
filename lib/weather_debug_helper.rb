# frozen_string_literal: true

# Rails consoleで天気データをデバッグするためのヘルパー
# 使い方: 
#   require 'weather_debug_helper'
#   WeatherDebugHelper.check_farm(1)
#   WeatherDebugHelper.check_all_farms

module WeatherDebugHelper
  def self.check_farm(farm_id)
    farm = Farm.find(farm_id)
    puts "=" * 70
    puts "農場情報"
    puts "=" * 70
    puts "ID: #{farm.id}"
    puts "名前: #{farm.name}"
    puts "緯度: #{farm.latitude} (#{farm.latitude.class})"
    puts "経度: #{farm.longitude} (#{farm.longitude.class})"
    puts "天気ステータス: #{farm.weather_data_status}"
    puts "進捗: #{farm.weather_data_fetched_years}/#{farm.weather_data_total_years}"
    puts "WeatherLocation関連付け: #{farm.weather_location_id || 'なし'}"
    puts

    # 直接の関連付けを確認
    puts "=" * 70
    puts "WeatherLocation関連"
    puts "=" * 70
    
    if farm.weather_location
      puts "✅ 直接関連: WeatherLocation##{farm.weather_location.id}"
      data_count = farm.weather_location.weather_data.count
      puts "   データ数: #{data_count}"
    else
      puts "❌ 直接関連なし - 座標検索を試みます"
    end
    puts

    # WeatherLocationを検索
    puts "=" * 70
    puts "座標による検索"
    puts "=" * 70
    
    # 完全一致
    exact = WeatherLocation.find_by(latitude: farm.latitude, longitude: farm.longitude)
    if exact
      puts "✅ 完全一致: WeatherLocation##{exact.id}"
    else
      puts "❌ 完全一致: なし"
    end

    # 近似マッチ（許容範囲: 0.01度 ≈ 1.1km）
    tolerance = 0.01
    nearby = WeatherLocation.where(
      'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
      farm.latitude, tolerance,
      farm.longitude, tolerance
    ).order(
      Arel.sql("(ABS(latitude - #{farm.latitude.to_f}) + ABS(longitude - #{farm.longitude.to_f}))")
    )
    
    puts "近似マッチ (±#{tolerance}): #{nearby.count}件"
    nearby.each do |loc|
      lat_diff = (loc.latitude.to_f - farm.latitude.to_f).abs
      lon_diff = (loc.longitude.to_f - farm.longitude.to_f).abs
      puts "  WeatherLocation##{loc.id}: (#{loc.latitude}, #{loc.longitude})"
      puts "    差分: 緯度 #{format('%.10f', lat_diff)}, 経度 #{format('%.10f', lon_diff)}"
    end
    puts

    # 天気データ
    location = exact || nearby.first
    if location
      puts "=" * 70
      puts "天気データ (WeatherLocation##{location.id})"
      puts "=" * 70
      
      total = location.weather_data.count
      puts "総データ数: #{total}"
      
      if total > 0
        earliest = location.weather_data.order(:date).first
        latest = location.weather_data.order(:date).last
        puts "期間: #{earliest.date} ～ #{latest.date}"
        
        # 直近5件
        puts "\n直近5件:"
        location.weather_data.order(date: :desc).limit(5).each do |d|
          puts "  #{d.date}: 最高 #{d.temperature_max}℃, 最低 #{d.temperature_min}℃, 平均 #{d.temperature_mean}℃"
        end
      end
    else
      puts "=" * 70
      puts "❌ WeatherLocationが見つかりません"
      puts "=" * 70
      puts "全WeatherLocation (#{WeatherLocation.count}件):"
      WeatherLocation.all.each do |loc|
        puts "  ##{loc.id}: (#{loc.latitude}, #{loc.longitude}) - データ数: #{loc.weather_data.count}"
      end
    end
    
    puts "=" * 70
    nil
  end

  def self.check_all_farms
    puts "=" * 70
    puts "全農場の状況"
    puts "=" * 70
    
    Farm.all.each do |farm|
      puts "\n農場##{farm.id}: #{farm.name}"
      puts "  位置: (#{farm.latitude}, #{farm.longitude})"
      puts "  ステータス: #{farm.weather_data_status} (#{farm.weather_data_progress}%)"
      puts "  WeatherLocation関連: #{farm.weather_location_id ? "✅ ##{farm.weather_location_id}" : "❌ なし"}"
      
      # 直接の関連を優先
      location = farm.weather_location
      
      # なければ座標検索
      if location.nil?
        tolerance = 0.0001
        location = WeatherLocation.where(
          'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
          farm.latitude, tolerance,
          farm.longitude, tolerance
        ).first
      end
      
      if location
        data_count = location.weather_data.count
        if data_count > 0
          earliest = location.weather_data.order(:date).first.date
          latest = location.weather_data.order(:date).last.date
          puts "  ✅ WeatherLocation##{location.id} (#{data_count}件: #{earliest}～#{latest})"
        else
          puts "  ⚠️  WeatherLocation##{location.id} あるがデータなし"
        end
      else
        puts "  ❌ WeatherLocationなし"
      end
    end
    
    puts "\n" + "=" * 70
    nil
  end

  def self.test_api_call(farm_id)
    require 'net/http'
    require 'json'
    
    farm = Farm.find(farm_id)
    
    end_date = Date.today
    start_date = end_date - 365
    
    url = "http://localhost:3000/farms/#{farm_id}/weather_data?start_date=#{start_date}&end_date=#{end_date}"
    
    puts "=" * 70
    puts "API呼び出しテスト"
    puts "=" * 70
    puts "URL: #{url}"
    puts
    
    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      result = JSON.parse(response.body)
      
      puts "ステータスコード: #{response.code}"
      puts "レスポンス:"
      puts JSON.pretty_generate(result)
    rescue => e
      puts "エラー: #{e.message}"
    end
    
    puts "=" * 70
    nil
  end
end

