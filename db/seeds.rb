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
  
  weather_fixture.each do |farm_name, farm_data|
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
  puts "   Total weather records: #{WeatherDatum.joins(weather_location: :farms).where(farms: { is_reference: true }).distinct.count}"
  
else
  # フィクスチャファイルがない場合、基本情報のみ作成
  puts "⚠️  Weather fixture not found. Creating farms without weather data."
  puts "   Run 'bin/fetch_reference_weather_data' to generate fixture with complete weather data."
  
  reference_farms = [
    # 北海道・東北（7地域）
    { name: '北海道', latitude: 43.0642, longitude: 141.3469 },  # 札幌
    { name: '青森', latitude: 40.8244, longitude: 140.7400 },
    { name: '岩手', latitude: 39.7036, longitude: 141.1527 },    # 盛岡
    { name: '宮城', latitude: 38.2682, longitude: 140.8720 },    # 仙台
    { name: '秋田', latitude: 39.7186, longitude: 140.1028 },
    { name: '山形', latitude: 38.2404, longitude: 140.3633 },
    { name: '福島', latitude: 37.7500, longitude: 140.4673 },
    # 関東（7地域）
    { name: '茨城', latitude: 36.3414, longitude: 140.4467 },    # 水戸
    { name: '栃木', latitude: 36.5658, longitude: 139.8836 },    # 宇都宮
    { name: '群馬', latitude: 36.3911, longitude: 139.0608 },    # 前橋
    { name: '埼玉', latitude: 35.8569, longitude: 139.6489 },    # さいたま
    { name: '千葉', latitude: 35.6074, longitude: 140.1061 },
    { name: '東京', latitude: 35.6762, longitude: 139.6503 },
    { name: '神奈川', latitude: 35.4478, longitude: 139.6425 },  # 横浜
    # 中部（9地域）
    { name: '新潟', latitude: 37.9022, longitude: 139.0233 },
    { name: '富山', latitude: 36.6959, longitude: 137.2137 },
    { name: '石川', latitude: 36.5946, longitude: 136.6256 },    # 金沢
    { name: '福井', latitude: 36.0652, longitude: 136.2216 },
    { name: '山梨', latitude: 35.6636, longitude: 138.5684 },    # 甲府
    { name: '長野', latitude: 36.6513, longitude: 138.1811 },
    { name: '岐阜', latitude: 35.3912, longitude: 136.7223 },
    { name: '静岡', latitude: 34.9769, longitude: 138.3831 },
    { name: '愛知', latitude: 35.1815, longitude: 136.9066 },    # 名古屋
    # 近畿（7地域）
    { name: '三重', latitude: 34.7303, longitude: 136.5086 },    # 津
    { name: '滋賀', latitude: 35.0045, longitude: 135.8686 },    # 大津
    { name: '京都', latitude: 35.0116, longitude: 135.7681 },
    { name: '大阪', latitude: 34.6937, longitude: 135.5023 },
    { name: '兵庫', latitude: 34.6901, longitude: 135.1955 },    # 神戸
    { name: '奈良', latitude: 34.6851, longitude: 135.8329 },
    { name: '和歌山', latitude: 34.2261, longitude: 135.1675 },
    # 中国・四国（9地域）
    { name: '鳥取', latitude: 35.5014, longitude: 134.2350 },
    { name: '島根', latitude: 35.4723, longitude: 133.0505 },    # 松江
    { name: '岡山', latitude: 34.6617, longitude: 133.9350 },
    { name: '広島', latitude: 34.3963, longitude: 132.4596 },
    { name: '山口', latitude: 34.1858, longitude: 131.4706 },
    { name: '徳島', latitude: 34.0658, longitude: 134.5594 },
    { name: '香川', latitude: 34.3401, longitude: 134.0434 },    # 高松
    { name: '愛媛', latitude: 33.8416, longitude: 132.7657 },    # 松山
    { name: '高知', latitude: 33.5597, longitude: 133.5311 },
    # 九州・沖縄（8地域）
    { name: '福岡', latitude: 33.5904, longitude: 130.4017 },
    { name: '佐賀', latitude: 33.2494, longitude: 130.2989 },
    { name: '長崎', latitude: 32.7503, longitude: 129.8779 },
    { name: '熊本', latitude: 32.7898, longitude: 130.7417 },
    { name: '大分', latitude: 33.2382, longitude: 131.6126 },
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
  # フィクスチャファイルがない場合、基本情報のみ作成
  puts "⚠️  Crop fixture not found. Creating crops without AI data."
  puts "   Run 'bin/fetch_reference_crop_info' to generate fixture with complete crop information."
  
  reference_crops = [
    { name: 'トマト', variety: '大玉', is_reference: true },
    { name: 'ジャガイモ', variety: '男爵', is_reference: true },
    { name: '玉ねぎ', variety: '黄玉ねぎ', is_reference: true },
    { name: 'キャベツ', variety: '春キャベツ', is_reference: true },
    { name: 'ニンジン', variety: '五寸ニンジン', is_reference: true },
    { name: 'レタス', variety: '結球レタス', is_reference: true },
    { name: 'ほうれん草', variety: '一般', is_reference: true },
    { name: 'ナス', variety: '千両二号', is_reference: true },
    { name: 'キュウリ', variety: '白イボ', is_reference: true },
    { name: 'ピーマン', variety: '京みどり', is_reference: true },
    { name: '大根', variety: '青首大根', is_reference: true },
    { name: 'ブロッコリー', variety: '一般', is_reference: true },
    { name: '白菜', variety: '結球白菜', is_reference: true },
    { name: 'とうもろこし', variety: 'スイートコーン', is_reference: true },
    { name: 'かぼちゃ', variety: '西洋かぼちゃ', is_reference: true }
  ]
  
  reference_crops.each do |crop_data|
    Crop.find_or_create_by!(name: crop_data[:name], variety: crop_data[:variety], is_reference: true) do |crop|
      crop.user_id = nil
      crop.is_reference = crop_data[:is_reference]
    end
  end
  
  puts "✅ Created #{Crop.reference.count} reference crops (basic info only)"
end

puts "🎉 Seeding completed!"
puts ""
puts "Summary:"
puts "  Admin Users: #{User.where(admin: true).count}"
puts "  Reference Farms: #{Farm.where(is_reference: true).count}"
puts "  Reference Crops: #{Crop.reference.count}"



