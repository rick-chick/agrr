# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Admin User（管理者ユーザー）
# モックログインの開発者ユーザーと同じ認証情報を使用
puts "Creating admin user..."
admin = User.find_or_create_by!(google_id: 'dev_user_001') do |user|
  user.email = 'developer@agrr.dev'
  user.name = '開発者'
  user.admin = true
  user.is_anonymous = false
end

# 既存ユーザーの場合も管理者権限を確保
unless admin.admin?
  admin.update!(admin: true)
end

puts "✅ Created admin user: #{admin.email} (admin: #{admin.admin})"

# Reference Farms（日本の主要農業地域）
puts "Creating reference farms for Japan..."

# フィクスチャファイルのパス
weather_fixture_path = Rails.root.join('db/fixtures/reference_weather.json')

if weather_fixture_path.exist?
  # フィクスチャファイルが存在する場合、天気データ込みで投入
  puts "✅ Loading reference weather data from fixture..."
  weather_fixture = JSON.parse(File.read(weather_fixture_path))
  
  # 緯度順（北から南）にソートして処理
  sorted_farms = weather_fixture.sort_by { |farm_name, farm_data| -farm_data['latitude'].to_f }
  
  sorted_farms.each do |farm_name, farm_data|
    # 農場を作成
    farm = Farm.find_or_create_by!(name: farm_name, is_reference: true) do |f|
      f.user = User.anonymous_user
      f.latitude = farm_data['latitude']
      f.longitude = farm_data['longitude']
    end
    
    # WeatherLocationを作成
    if farm_data['weather_location']
      wl_data = farm_data['weather_location']
      weather_location = WeatherLocation.find_or_create_by!(
        latitude: wl_data['latitude'],
        longitude: wl_data['longitude']
      ) do |wl|
        wl.elevation = wl_data['elevation']
        wl.timezone = wl_data['timezone']
      end
      
      # Farmとweather_locationを関連付け
      unless farm.weather_location_id == weather_location.id
        farm.update_column(:weather_location_id, weather_location.id)
      end
      
      # WeatherDataを一括投入
      if farm_data['weather_data']&.any?
        weather_records = farm_data['weather_data'].map do |wd|
          {
            weather_location_id: weather_location.id,
            date: Date.parse(wd['date']),
            temperature_max: wd['temperature_max'],
            temperature_min: wd['temperature_min'],
            temperature_mean: wd['temperature_mean'],
            precipitation: wd['precipitation'],
            sunshine_hours: wd['sunshine_hours'],
            wind_speed: wd['wind_speed'],
            weather_code: wd['weather_code'],
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        
        WeatherDatum.upsert_all(
          weather_records,
          unique_by: [:weather_location_id, :date]
        ) if weather_records.any?
        
        # 進捗情報を更新
        total_blocks = ((Date.today.year - 2000 + 1) / 5.0).ceil
        farm.update_columns(
          weather_data_status: 'completed',
          weather_data_fetched_years: total_blocks,
          weather_data_total_years: total_blocks
        )
      end
    end
  end
  
  puts "✅ Created #{Farm.where(is_reference: true).count} reference farms with weather data"
  weather_location_ids = Farm.where(is_reference: true).pluck(:weather_location_id).compact.uniq
  total_weather_records = WeatherDatum.where(weather_location_id: weather_location_ids).count
  puts "   Total weather records: #{total_weather_records}"
  
else
  # フィクスチャファイルがない場合、基本情報のみ作成
  puts "⚠️  Weather fixture not found. Creating farms without weather data."
  puts "   Run 'bin/fetch_reference_weather_data' to generate fixture with complete weather data."
  
  reference_farms = [
    # 北から南の順（緯度降順）
    { name: '北海道', latitude: 43.0642, longitude: 141.3469 },  # 札幌
    { name: '青森', latitude: 40.8244, longitude: 140.7400 },
    { name: '岩手', latitude: 39.7036, longitude: 141.1527 },    # 盛岡
    { name: '秋田', latitude: 39.7186, longitude: 140.1028 },
    { name: '宮城', latitude: 38.2682, longitude: 140.8720 },    # 仙台
    { name: '山形', latitude: 38.2404, longitude: 140.3633 },
    { name: '新潟', latitude: 37.9022, longitude: 139.0233 },
    { name: '福島', latitude: 37.7500, longitude: 140.4673 },
    { name: '富山', latitude: 36.6959, longitude: 137.2137 },
    { name: '長野', latitude: 36.6513, longitude: 138.1811 },
    { name: '石川', latitude: 36.5946, longitude: 136.6256 },    # 金沢
    { name: '栃木', latitude: 36.5658, longitude: 139.8836 },    # 宇都宮
    { name: '群馬', latitude: 36.3911, longitude: 139.0608 },    # 前橋
    { name: '茨城', latitude: 36.3414, longitude: 140.4467 },    # 水戸
    { name: '福井', latitude: 36.0652, longitude: 136.2216 },
    { name: '埼玉', latitude: 35.8569, longitude: 139.6489 },    # さいたま
    { name: '東京', latitude: 35.6762, longitude: 139.6503 },
    { name: '山梨', latitude: 35.6636, longitude: 138.5684 },    # 甲府
    { name: '千葉', latitude: 35.6074, longitude: 140.1061 },
    { name: '鳥取', latitude: 35.5014, longitude: 134.2350 },
    { name: '島根', latitude: 35.4723, longitude: 133.0505 },    # 松江
    { name: '神奈川', latitude: 35.4478, longitude: 139.6425 },  # 横浜
    { name: '岐阜', latitude: 35.3912, longitude: 136.7223 },
    { name: '愛知', latitude: 35.1815, longitude: 136.9066 },    # 名古屋
    { name: '京都', latitude: 35.0116, longitude: 135.7681 },
    { name: '滋賀', latitude: 35.0045, longitude: 135.8686 },    # 大津
    { name: '静岡', latitude: 34.9769, longitude: 138.3831 },
    { name: '三重', latitude: 34.7303, longitude: 136.5086 },    # 津
    { name: '大阪', latitude: 34.6937, longitude: 135.5023 },
    { name: '兵庫', latitude: 34.6901, longitude: 135.1955 },    # 神戸
    { name: '奈良', latitude: 34.6851, longitude: 135.8329 },
    { name: '岡山', latitude: 34.6617, longitude: 133.9350 },
    { name: '広島', latitude: 34.3963, longitude: 132.4596 },
    { name: '和歌山', latitude: 34.2261, longitude: 135.1675 },
    { name: '山口', latitude: 34.1858, longitude: 131.4706 },
    { name: '徳島', latitude: 34.0658, longitude: 134.5594 },
    { name: '香川', latitude: 34.3401, longitude: 134.0434 },    # 高松
    { name: '愛媛', latitude: 33.8416, longitude: 132.7657 },    # 松山
    { name: '福岡', latitude: 33.5904, longitude: 130.4017 },
    { name: '高知', latitude: 33.5597, longitude: 133.5311 },
    { name: '佐賀', latitude: 33.2494, longitude: 130.2989 },
    { name: '大分', latitude: 33.2382, longitude: 131.6126 },
    { name: '熊本', latitude: 32.7898, longitude: 130.7417 },
    { name: '長崎', latitude: 32.7503, longitude: 129.8779 },
    { name: '宮崎', latitude: 31.9077, longitude: 131.4202 },
    { name: '鹿児島', latitude: 31.5966, longitude: 130.5571 },
    { name: '沖縄', latitude: 26.2124, longitude: 127.6809 }     # 那覇
  ]
  
  reference_farms.each do |farm_data|
    Farm.find_or_create_by!(name: farm_data[:name], is_reference: true) do |farm|
      farm.user = User.anonymous_user
      farm.latitude = farm_data[:latitude]
      farm.longitude = farm_data[:longitude]
    end
  end
  
  puts "✅ Created #{Farm.where(is_reference: true).count} reference farms (basic info only)"
end

# Reference Crops（参照用作物）
puts "Creating reference crops..."

# フィクスチャファイルのパス
crop_fixture_path = Rails.root.join('db/fixtures/reference_crops.json')

if crop_fixture_path.exist?
  # フィクスチャファイルが存在する場合、AI情報込みで投入
  puts "✅ Loading reference crop data from fixture..."
  crop_fixture = JSON.parse(File.read(crop_fixture_path))
  
  crop_fixture.each do |crop_name, crop_data|
    crop = Crop.find_or_create_by!(name: crop_name, variety: crop_data['variety'], is_reference: true) do |c|
      c.user_id = nil
      c.area_per_unit = crop_data['area_per_unit']
      c.revenue_per_area = crop_data['revenue_per_area']
    end
    
    # CropStagesを作成
    crop_data['crop_stages']&.each do |stage_data|
      stage = crop.crop_stages.find_or_create_by!(order: stage_data['order']) do |s|
        s.name = stage_data['name']
      end
      
      # Temperature Requirement
      if stage_data['temperature_requirement']
        temp_req = stage_data['temperature_requirement']
        if stage.temperature_requirement
          stage.temperature_requirement.update!(
            base_temperature: temp_req['base_temperature'],
            optimal_min: temp_req['optimal_min'],
            optimal_max: temp_req['optimal_max'],
            low_stress_threshold: temp_req['low_stress_threshold'],
            high_stress_threshold: temp_req['high_stress_threshold'],
            frost_threshold: temp_req['frost_threshold'],
            sterility_risk_threshold: temp_req['sterility_risk_threshold']
          )
        else
          stage.create_temperature_requirement!(
            base_temperature: temp_req['base_temperature'],
            optimal_min: temp_req['optimal_min'],
            optimal_max: temp_req['optimal_max'],
            low_stress_threshold: temp_req['low_stress_threshold'],
            high_stress_threshold: temp_req['high_stress_threshold'],
            frost_threshold: temp_req['frost_threshold'],
            sterility_risk_threshold: temp_req['sterility_risk_threshold']
          )
        end
      end
      
      # Sunshine Requirement
      if stage_data['sunshine_requirement']
        sun_req = stage_data['sunshine_requirement']
        if stage.sunshine_requirement
          stage.sunshine_requirement.update!(
            minimum_sunshine_hours: sun_req['minimum_sunshine_hours'],
            target_sunshine_hours: sun_req['target_sunshine_hours']
          )
        else
          stage.create_sunshine_requirement!(
            minimum_sunshine_hours: sun_req['minimum_sunshine_hours'],
            target_sunshine_hours: sun_req['target_sunshine_hours']
          )
        end
      end
      
      # Thermal Requirement
      if stage_data['thermal_requirement']
        thermal_req = stage_data['thermal_requirement']
        if stage.thermal_requirement
          stage.thermal_requirement.update!(
            required_gdd: thermal_req['required_gdd']
          )
        else
          stage.create_thermal_requirement!(
            required_gdd: thermal_req['required_gdd']
          )
        end
      end
    end
  end
  
  puts "✅ Created #{Crop.reference.count} reference crops with AI data"
  puts "   Total crop stages: #{CropStage.joins(:crop).where(crops: { is_reference: true }).count}"
else
  puts "⚠️  Crop fixture not found at #{crop_fixture_path}"
  puts "   Run 'bin/fetch_reference_crop_info' to generate fixture with complete crop information."
  puts "   Skipping reference crop creation."
end

# Fields（圃場）
puts "Creating sample fields for reference farms..."

reference_farms = Farm.where(is_reference: true).limit(5)
field_count = 0

reference_farms.each_with_index do |farm, farm_index|
  # 各農場に2-3の圃場を作成（農場名をプレフィックスとして使用してユニーク性を確保）
  farm_prefix = farm.name.gsub(/[県市]/, '').strip.first(3)
  
  fields_data = [
    { name: "#{farm_prefix}_第1圃場", area: 1000.0, daily_fixed_cost: 3000.0 },
    { name: "#{farm_prefix}_第2圃場", area: 1500.0, daily_fixed_cost: 4500.0 },
    { name: "#{farm_prefix}_第3圃場", area: 800.0, daily_fixed_cost: 2500.0 }
  ]
  
  fields_data.first(farm_index % 2 + 2).each do |field_data|
    Field.find_or_create_by!(farm: farm, name: field_data[:name]) do |field|
      field.user = farm.user
      field.area = field_data[:area]
      field.daily_fixed_cost = field_data[:daily_fixed_cost]
      field.latitude = farm.latitude + rand(-0.01..0.01) if farm.latitude
      field.longitude = farm.longitude + rand(-0.01..0.01) if farm.longitude
    end
    field_count += 1
  end
end

puts "✅ Created #{field_count} sample fields"

puts "🎉 Seeding completed!"
puts ""
puts "Summary:"
puts "  Admin Users: #{User.where(admin: true).count}"
puts "  Reference Farms: #{Farm.where(is_reference: true).count}"
puts "  Reference Crops: #{Crop.reference.count}"
puts "  Sample Fields: #{Field.count}"



