# frozen_string_literal: true

class SeedJapanReferenceData < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計
  
  class TempUser < ActiveRecord::Base
    self.table_name = 'users'
  end
  
  class TempFarm < ActiveRecord::Base
    self.table_name = 'farms'
  end
  
  class TempWeatherLocation < ActiveRecord::Base
    self.table_name = 'weather_locations'
  end
  
  class TempWeatherDatum < ActiveRecord::Base
    self.table_name = 'weather_data'
  end
  
  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
    has_many :crop_stages, class_name: 'SeedJapanReferenceData::TempCropStage', foreign_key: 'crop_id'
  end
  
  class TempCropStage < ActiveRecord::Base
    self.table_name = 'crop_stages'
    belongs_to :crop, class_name: 'SeedJapanReferenceData::TempCrop', foreign_key: 'crop_id'
  end
  
  class TempTemperatureRequirement < ActiveRecord::Base
    self.table_name = 'temperature_requirements'
  end
  
  class TempThermalRequirement < ActiveRecord::Base
    self.table_name = 'thermal_requirements'
  end
  
  class TempSunshineRequirement < ActiveRecord::Base
    self.table_name = 'sunshine_requirements'
  end
  
  class TempField < ActiveRecord::Base
    self.table_name = 'fields'
  end
  
  class TempInteractionRule < ActiveRecord::Base
    self.table_name = 'interaction_rules'
  end
  
  def up
    say "🌱 Seeding Japan (jp) reference data..."
    
    # 1. Admin User
    seed_admin_user
    
    # 2. Reference Farms + Weather Data
    seed_reference_farms_and_weather
    
    # 3. Reference Crops
    seed_reference_crops
    
    # 4. Sample Fields
    seed_sample_fields
    
    # 5. Interaction Rules
    seed_interaction_rules
    
    say "✅ Japan reference data seeding completed!"
  end
  
  def down
    say "🗑️  Removing Japan (jp) reference data..."
    
    # 逆順で削除
    TempInteractionRule.where(region: 'jp').delete_all
    TempField.where(region: 'jp').delete_all
    
    # Crops関連（外部キー制約を考慮）
    jp_crop_ids = TempCrop.where(region: 'jp', is_reference: true).pluck(:id)
    jp_crop_stage_ids = TempCropStage.where(crop_id: jp_crop_ids).pluck(:id)
    
    TempSunshineRequirement.where(crop_stage_id: jp_crop_stage_ids).delete_all
    TempThermalRequirement.where(crop_stage_id: jp_crop_stage_ids).delete_all
    TempTemperatureRequirement.where(crop_stage_id: jp_crop_stage_ids).delete_all
    TempCropStage.where(crop_id: jp_crop_ids).delete_all
    TempCrop.where(region: 'jp', is_reference: true).delete_all
    
    # Farms関連
    jp_farm_ids = TempFarm.where(region: 'jp', is_reference: true).pluck(:id)
    jp_weather_location_ids = TempFarm.where(id: jp_farm_ids).pluck(:weather_location_id).compact.uniq
    
    TempWeatherDatum.where(weather_location_id: jp_weather_location_ids).delete_all
    TempWeatherLocation.where(id: jp_weather_location_ids).delete_all
    TempFarm.where(region: 'jp', is_reference: true).delete_all
    
    say "✅ Japan reference data removed"
  end
  
  private
  
  def seed_admin_user
    say_with_time "Creating admin user..." do
      # Anonymous userを取得（既に存在する前提）
      anonymous = TempUser.find_by(is_anonymous: true)
      unless anonymous
        anonymous = TempUser.create!(
          email: nil,
          name: 'Anonymous',
          is_anonymous: true
        )
      end
      
      # Admin user作成
      admin = TempUser.find_or_initialize_by(google_id: 'dev_user_001')
      admin.assign_attributes(
        email: 'developer@agrr.dev',
        name: '開発者',
        admin: true,
        is_anonymous: false
      )
      admin.save!
      
      1 # 処理件数を返す
    end
  end
  
  def seed_reference_farms_and_weather
    fixture_path = Rails.root.join('db/fixtures/reference_weather.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  Fixture not found: #{fixture_path}", true
      return create_basic_farms_without_weather
    end
    
    say_with_time "Loading reference farms with weather data from fixture..." do
      weather_fixture = JSON.parse(File.read(fixture_path))
      sorted_farms = weather_fixture.sort_by { |farm_name, farm_data| -farm_data['latitude'].to_f }
      
      count = 0
      sorted_farms.each do |farm_name, farm_data|
        # Anonymous userを取得
        anonymous_user = TempUser.find_by(is_anonymous: true)
        
        # Farm作成
        farm = TempFarm.find_or_initialize_by(name: farm_name, is_reference: true, region: 'jp')
        farm.assign_attributes(
          user_id: anonymous_user.id,
          latitude: farm_data['latitude'],
          longitude: farm_data['longitude']
        )
        farm.save!
        
        # WeatherLocation作成
        if farm_data['weather_location']
          wl_data = farm_data['weather_location']
          weather_location = TempWeatherLocation.find_or_create_by!(
            latitude: wl_data['latitude'],
            longitude: wl_data['longitude']
          ) do |wl|
            wl.elevation = wl_data['elevation']
            wl.timezone = wl_data['timezone']
          end
          
          farm.update_column(:weather_location_id, weather_location.id) unless farm.weather_location_id == weather_location.id
          
          # WeatherData一括投入
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
            
            TempWeatherDatum.upsert_all(
              weather_records,
              unique_by: [:weather_location_id, :date]
            ) if weather_records.any?
            
            # 進捗情報更新
            total_blocks = ((Date.today.year - 2000 + 1) / 5.0).ceil
            farm.update_columns(
              weather_data_status: 'completed',
              weather_data_fetched_years: total_blocks,
              weather_data_total_years: total_blocks
            )
          end
        end
        
        count += 1
      end
      
      count
    end
  end
  
  def create_basic_farms_without_weather
    say_with_time "Creating basic farms without weather data..." do
      reference_farms = [
        { name: '北海道', latitude: 43.0642, longitude: 141.3469 },
        { name: '青森', latitude: 40.8244, longitude: 140.7400 },
        { name: '岩手', latitude: 39.7036, longitude: 141.1527 },
        { name: '秋田', latitude: 39.7186, longitude: 140.1028 },
        { name: '宮城', latitude: 38.2682, longitude: 140.8720 },
        { name: '山形', latitude: 38.2404, longitude: 140.3633 },
        { name: '新潟', latitude: 37.9022, longitude: 139.0233 },
        { name: '福島', latitude: 37.7500, longitude: 140.4673 },
        { name: '富山', latitude: 36.6959, longitude: 137.2137 },
        { name: '長野', latitude: 36.6513, longitude: 138.1811 },
        { name: '石川', latitude: 36.5946, longitude: 136.6256 },
        { name: '栃木', latitude: 36.5658, longitude: 139.8836 },
        { name: '群馬', latitude: 36.3911, longitude: 139.0608 },
        { name: '茨城', latitude: 36.3414, longitude: 140.4467 },
        { name: '福井', latitude: 36.0652, longitude: 136.2216 },
        { name: '埼玉', latitude: 35.8569, longitude: 139.6489 },
        { name: '東京', latitude: 35.6762, longitude: 139.6503 },
        { name: '山梨', latitude: 35.6636, longitude: 138.5684 },
        { name: '千葉', latitude: 35.6074, longitude: 140.1061 },
        { name: '鳥取', latitude: 35.5014, longitude: 134.2350 },
        { name: '島根', latitude: 35.4723, longitude: 133.0505 },
        { name: '神奈川', latitude: 35.4478, longitude: 139.6425 },
        { name: '岐阜', latitude: 35.3912, longitude: 136.7223 },
        { name: '愛知', latitude: 35.1815, longitude: 136.9066 },
        { name: '京都', latitude: 35.0116, longitude: 135.7681 },
        { name: '滋賀', latitude: 35.0045, longitude: 135.8686 },
        { name: '静岡', latitude: 34.9769, longitude: 138.3831 },
        { name: '三重', latitude: 34.7303, longitude: 136.5086 },
        { name: '大阪', latitude: 34.6937, longitude: 135.5023 },
        { name: '兵庫', latitude: 34.6901, longitude: 135.1955 },
        { name: '奈良', latitude: 34.6851, longitude: 135.8329 },
        { name: '岡山', latitude: 34.6617, longitude: 133.9350 },
        { name: '広島', latitude: 34.3963, longitude: 132.4596 },
        { name: '和歌山', latitude: 34.2261, longitude: 135.1675 },
        { name: '山口', latitude: 34.1858, longitude: 131.4706 },
        { name: '徳島', latitude: 34.0658, longitude: 134.5594 },
        { name: '香川', latitude: 34.3401, longitude: 134.0434 },
        { name: '愛媛', latitude: 33.8416, longitude: 132.7657 },
        { name: '福岡', latitude: 33.5904, longitude: 130.4017 },
        { name: '高知', latitude: 33.5597, longitude: 133.5311 },
        { name: '佐賀', latitude: 33.2494, longitude: 130.2989 },
        { name: '大分', latitude: 33.2382, longitude: 131.6126 },
        { name: '熊本', latitude: 32.7898, longitude: 130.7417 },
        { name: '長崎', latitude: 32.7503, longitude: 129.8779 },
        { name: '宮崎', latitude: 31.9077, longitude: 131.4202 },
        { name: '鹿児島', latitude: 31.5966, longitude: 130.5571 },
        { name: '沖縄', latitude: 26.2124, longitude: 127.6809 }
      ]
      
      anonymous_user = TempUser.find_by(is_anonymous: true)
      
      reference_farms.each do |farm_data|
        TempFarm.find_or_create_by!(name: farm_data[:name], is_reference: true, region: 'jp') do |f|
          f.user_id = anonymous_user.id
          f.latitude = farm_data[:latitude]
          f.longitude = farm_data[:longitude]
        end
      end
      
      reference_farms.size
    end
  end
  
  def seed_reference_crops
    fixture_path = Rails.root.join('db/fixtures/reference_crops.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  Crop fixture not found: #{fixture_path}", true
      return 0
    end
    
    say_with_time "Loading reference crops from fixture..." do
      crop_fixture = JSON.parse(File.read(fixture_path))
      count = 0
      
      crop_fixture.each do |crop_name, crop_data|
        crop = TempCrop.find_or_initialize_by(name: crop_name, variety: crop_data['variety'], is_reference: true, region: 'jp')
        crop.assign_attributes(
          user_id: nil,
          groups: crop_data['groups'].to_json, # JSON文字列として保存
          area_per_unit: crop_data['area_per_unit'],
          revenue_per_area: crop_data['revenue_per_area']
        )
        crop.save!
        
        # CropStages作成
        crop_data['crop_stages']&.each do |stage_data|
          stage = TempCropStage.find_or_initialize_by(crop_id: crop.id, order: stage_data['order'])
          stage.name = stage_data['name']
          stage.save!
          
          # Temperature Requirement
          if stage_data['temperature_requirement']
            temp_req = stage_data['temperature_requirement']
            TempTemperatureRequirement.find_or_initialize_by(crop_stage_id: stage.id).tap do |tr|
              tr.assign_attributes(
                base_temperature: temp_req['base_temperature'],
                optimal_min: temp_req['optimal_min'],
                optimal_max: temp_req['optimal_max'],
                low_stress_threshold: temp_req['low_stress_threshold'],
                high_stress_threshold: temp_req['high_stress_threshold'],
                frost_threshold: temp_req['frost_threshold'],
                sterility_risk_threshold: temp_req['sterility_risk_threshold'],
                max_temperature: temp_req['max_temperature']
              )
              tr.save!
            end
          end
          
          # Sunshine Requirement
          if stage_data['sunshine_requirement']
            sun_req = stage_data['sunshine_requirement']
            TempSunshineRequirement.find_or_initialize_by(crop_stage_id: stage.id).tap do |sr|
              sr.assign_attributes(
                minimum_sunshine_hours: sun_req['minimum_sunshine_hours'],
                target_sunshine_hours: sun_req['target_sunshine_hours']
              )
              sr.save!
            end
          end
          
          # Thermal Requirement
          if stage_data['thermal_requirement']
            thermal_req = stage_data['thermal_requirement']
            TempThermalRequirement.find_or_initialize_by(crop_stage_id: stage.id).tap do |tr|
              tr.assign_attributes(
                required_gdd: thermal_req['required_gdd']
              )
              tr.save!
            end
          end
        end
        
        count += 1
      end
      
      count
    end
  end
  
  def seed_sample_fields
    say_with_time "Creating sample fields for reference farms..." do
      reference_farms = TempFarm.where(is_reference: true, region: 'jp').limit(5)
      field_count = 0
      
      reference_farms.each_with_index do |farm, farm_index|
        farm_prefix = farm.name.gsub(/[県市]/, '').strip[0, 3]
        
        fields_data = [
          { name: "#{farm_prefix}_第1圃場", area: 1000.0, daily_fixed_cost: 3000.0 },
          { name: "#{farm_prefix}_第2圃場", area: 1500.0, daily_fixed_cost: 4500.0 },
          { name: "#{farm_prefix}_第3圃場", area: 800.0, daily_fixed_cost: 2500.0 }
        ]
        
      fields_data.first(farm_index % 2 + 2).each do |field_data|
        field = TempField.find_or_initialize_by(farm_id: farm.id, name: field_data[:name])
        attrs = {
          user_id: farm.user_id,
          area: field_data[:area],
          daily_fixed_cost: field_data[:daily_fixed_cost]
        }
        # latitude/longitudeカラムが存在する場合のみ設定
        if TempField.column_names.include?('latitude')
          attrs[:latitude] = farm.latitude ? farm.latitude + rand(-0.01..0.01) : nil
          attrs[:longitude] = farm.longitude ? farm.longitude + rand(-0.01..0.01) : nil
        end
        if TempField.column_names.include?('region')
          attrs[:region] = 'jp'
        end
        field.assign_attributes(attrs)
        field.save!
        field_count += 1
      end
      end
      
      field_count
    end
  end
  
  def seed_interaction_rules
    say_with_time "Creating interaction rules for Japan..." do
      # 参照作物のgroupsから科を抽出
      unique_families = TempCrop.where(is_reference: true, region: 'jp')
                               .pluck(:groups)
                               .map { |g| JSON.parse(g) }
                               .flatten
                               .compact
                               .uniq
                               .sort
      
      # 連作の影響度
      continuous_cultivation_impacts = {
        "ナス科" => { impact_ratio: 0.6, description: "ナス科の連作（非常に強い、収益40%減少）- トマト、ナス、ジャガイモ、ピーマンなど" },
        "ウリ科" => { impact_ratio: 0.65, description: "ウリ科の連作（非常に強い、収益35%減少）- キュウリ、カボチャ、スイカ、メロンなど" },
        "アブラナ科" => { impact_ratio: 0.75, description: "アブラナ科の連作（強い、収益25%減少）- キャベツ、白菜、大根、ブロッコリーなど" },
        "キク科" => { impact_ratio: 0.75, description: "キク科の連作（強い、収益25%減少）- レタス、ゴボウ、春菊など" },
        "セリ科" => { impact_ratio: 0.8, description: "セリ科の連作（中程度、収益20%減少）- ニンジン、セロリ、パセリ、三つ葉など" },
        "ネギ科" => { impact_ratio: 0.85, description: "ネギ科の連作（軽い、収益15%減少）- 玉ねぎ、長ネギ、ニラ、ニンニクなど" },
        "ヒユ科" => { impact_ratio: 0.9, description: "ヒユ科の連作（軽い、収益10%減少）- ほうれん草、ビートなど" },
        "イネ科" => { impact_ratio: 0.95, description: "イネ科の連作（ほとんどなし、収益5%減少）- とうもろこし、麦、イネなど" }
      }
      
      count = 0
      unique_families.each do |family|
        impact = continuous_cultivation_impacts[family] || {
          impact_ratio: 0.8,
          description: "#{family}の連作（中程度、収益20%減少）"
        }
        
        rule = TempInteractionRule.find_or_initialize_by(
          rule_type: 'continuous_cultivation',
          source_group: family,
          target_group: family,
          region: 'jp'
        )
        rule.assign_attributes(
          impact_ratio: impact[:impact_ratio],
          is_directional: true,
          is_reference: true,
          user_id: nil,
          description: impact[:description]
        )
        rule.save!
        count += 1
      end
      
      count
    end
  end
end
