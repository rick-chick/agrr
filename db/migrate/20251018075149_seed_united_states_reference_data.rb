# frozen_string_literal: true

class SeedUnitedStatesReferenceData < ActiveRecord::Migration[8.0]
  # 一時モデル定義（JPと同じ構造を使用）
  
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
    has_many :crop_stages, class_name: 'SeedUnitedStatesReferenceData::TempCropStage', foreign_key: 'crop_id'
  end
  
  class TempCropStage < ActiveRecord::Base
    self.table_name = 'crop_stages'
    belongs_to :crop, class_name: 'SeedUnitedStatesReferenceData::TempCrop', foreign_key: 'crop_id'
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
  
  class TempInteractionRule < ActiveRecord::Base
    self.table_name = 'interaction_rules'
  end
  
  def up
    say "🌱 Seeding United States (us) reference data..."
    
    # 1. Reference Farms + Weather Data
    seed_reference_farms_and_weather
    
    # 2. Reference Crops
    seed_reference_crops
    
    # 3. Interaction Rules
    seed_interaction_rules
    
    say "✅ United States reference data seeding completed!"
  end
  
  def down
    say "🗑️  Removing United States (us) reference data..."
    
    # 逆順で削除
    TempInteractionRule.where(region: 'us').delete_all
    
    # Crops関連
    us_crop_ids = TempCrop.where(region: 'us', is_reference: true).pluck(:id)
    us_crop_stage_ids = TempCropStage.where(crop_id: us_crop_ids).pluck(:id)
    
    TempSunshineRequirement.where(crop_stage_id: us_crop_stage_ids).delete_all
    TempThermalRequirement.where(crop_stage_id: us_crop_stage_ids).delete_all
    TempTemperatureRequirement.where(crop_stage_id: us_crop_stage_ids).delete_all
    TempCropStage.where(crop_id: us_crop_ids).delete_all
    TempCrop.where(region: 'us', is_reference: true).delete_all
    
    # Farms関連
    us_farm_ids = TempFarm.where(region: 'us', is_reference: true).pluck(:id)
    us_weather_location_ids = TempFarm.where(id: us_farm_ids).pluck(:weather_location_id).compact.uniq
    
    TempWeatherDatum.where(weather_location_id: us_weather_location_ids).delete_all
    TempWeatherLocation.where(id: us_weather_location_ids).delete_all
    TempFarm.where(region: 'us', is_reference: true).delete_all
    
    say "✅ United States reference data removed"
  end
  
  private
  
  def seed_reference_farms_and_weather
    fixture_path = Rails.root.join('db/fixtures/us_reference_weather.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  US fixture not found: #{fixture_path}", true
      return create_basic_farms_without_weather
    end
    
    say_with_time "Loading US reference farms with weather data from fixture..." do
      weather_fixture = JSON.parse(File.read(fixture_path))
      count = 0
      
      weather_fixture.each do |farm_name, farm_data|
        anonymous_user = TempUser.find_by(is_anonymous: true)
        
        # Farm作成
        farm = TempFarm.find_or_initialize_by(name: farm_name, is_reference: true, region: 'us')
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
            wl.timezone = wl_data['timezone'] || 'America/New_York'
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
    say_with_time "Creating basic US farms without weather data..." do
      us_reference_farms = [
        # California
        { name: 'Kern County, CA', latitude: 35.3733, longitude: -119.0187 },
        { name: 'Fresno County, CA', latitude: 36.7378, longitude: -119.7871 },
        { name: 'Tulare County, CA', latitude: 36.2079, longitude: -118.7903 },
        { name: 'Monterey County, CA', latitude: 36.6002, longitude: -121.8947 },
        { name: 'Merced County, CA', latitude: 37.3022, longitude: -120.4830 },
        
        # Iowa
        { name: 'Black Hawk County, IA', latitude: 42.4699, longitude: -92.3099 },
        { name: 'Linn County, IA', latitude: 42.0783, longitude: -91.5985 },
        { name: 'Scott County, IA', latitude: 41.6105, longitude: -90.6468 },
        { name: 'Polk County, IA', latitude: 41.6764, longitude: -93.5639 },
        { name: 'Johnson County, IA', latitude: 41.6611, longitude: -91.5302 },
        
        # Illinois
        { name: 'McLean County, IL', latitude: 40.4842, longitude: -88.9937 },
        { name: 'Champaign County, IL', latitude: 40.1164, longitude: -88.2434 },
        { name: 'LaSalle County, IL', latitude: 41.3433, longitude: -88.8617 },
        { name: 'Will County, IL', latitude: 41.4459, longitude: -88.0373 },
        { name: 'Adams County, IL', latitude: 40.0005, longitude: -91.1878 },
        
        # Nebraska
        { name: 'Lancaster County, NE', latitude: 40.7989, longitude: -96.6804 },
        { name: 'Douglas County, NE', latitude: 41.2587, longitude: -96.1253 },
        { name: 'Sarpy County, NE', latitude: 41.1167, longitude: -96.0503 },
        { name: 'Hall County, NE', latitude: 40.8708, longitude: -98.3420 },
        { name: 'Buffalo County, NE', latitude: 40.6572, longitude: -99.0634 },
        
        # Minnesota
        { name: 'Stearns County, MN', latitude: 45.5580, longitude: -94.6208 },
        { name: 'Wright County, MN', latitude: 45.1752, longitude: -93.9658 },
        { name: 'Olmsted County, MN', latitude: 43.9793, longitude: -92.4638 },
        { name: 'Blue Earth County, MN', latitude: 44.0541, longitude: -94.0719 },
        { name: 'Rice County, MN', latitude: 44.3483, longitude: -93.3111 },
        
        # Texas
        { name: 'Harris County, TX', latitude: 29.8582, longitude: -95.3935 },
        { name: 'Dallas County, TX', latitude: 32.7767, longitude: -96.7970 },
        { name: 'Tarrant County, TX', latitude: 32.7555, longitude: -97.3308 },
        { name: 'Bexar County, TX', latitude: 29.4241, longitude: -98.4936 },
        { name: 'Travis County, TX', latitude: 30.2672, longitude: -97.7431 },
        
        # Kansas
        { name: 'Sedgwick County, KS', latitude: 37.6872, longitude: -97.3301 },
        { name: 'Johnson County, KS', latitude: 38.8403, longitude: -94.8160 },
        { name: 'Shawnee County, KS', latitude: 39.0558, longitude: -95.7129 },
        { name: 'Wyandotte County, KS', latitude: 39.1147, longitude: -94.6275 },
        { name: 'Douglas County, KS', latitude: 38.9717, longitude: -95.2353 },
        
        # North Dakota
        { name: 'Cass County, ND', latitude: 46.8772, longitude: -97.0328 },
        { name: 'Burleigh County, ND', latitude: 46.8083, longitude: -100.7837 },
        { name: 'Grand Forks County, ND', latitude: 47.9253, longitude: -97.0329 },
        { name: 'Ward County, ND', latitude: 48.2330, longitude: -101.2955 },
        { name: 'Williams County, ND', latitude: 48.3308, longitude: -103.4244 },
        
        # South Dakota
        { name: 'Minnehaha County, SD', latitude: 43.6911, longitude: -96.7092 },
        { name: 'Pennington County, SD', latitude: 43.9950, longitude: -102.7618 },
        { name: 'Lincoln County, SD', latitude: 43.3547, longitude: -96.6656 },
        { name: 'Brown County, SD', latitude: 45.4397, longitude: -98.4865 },
        { name: 'Brookings County, SD', latitude: 44.3114, longitude: -96.7984 },
        
        # Wisconsin
        { name: 'Dane County, WI', latitude: 43.0731, longitude: -89.4012 },
        { name: 'Milwaukee County, WI', latitude: 43.0389, longitude: -87.9065 },
        { name: 'Waukesha County, WI', latitude: 43.0167, longitude: -88.2287 },
        { name: 'Brown County, WI', latitude: 44.5133, longitude: -88.0133 },
        { name: 'Racine County, WI', latitude: 42.7261, longitude: -87.7829 }
      ]
      
      anonymous_user = TempUser.find_by(is_anonymous: true)
      
      us_reference_farms.each do |farm_data|
        TempFarm.find_or_create_by!(name: farm_data[:name], is_reference: true, region: 'us') do |f|
          f.user_id = anonymous_user.id
          f.latitude = farm_data[:latitude]
          f.longitude = farm_data[:longitude]
        end
      end
      
      us_reference_farms.size
    end
  end
  
  def seed_reference_crops
    fixture_path = Rails.root.join('db/fixtures/us_reference_crops.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  US crop fixture not found: #{fixture_path}", true
      return create_basic_crops_without_ai_data
    end
    
    say_with_time "Loading US reference crops from fixture..." do
      crop_fixture = JSON.parse(File.read(fixture_path))
      count = 0
      
      crop_fixture.each do |crop_name, crop_data|
        crop = TempCrop.find_or_initialize_by(name: crop_name, variety: crop_data['variety'], is_reference: true, region: 'us')
        crop.assign_attributes(
          user_id: nil,
          groups: crop_data['groups'].to_json,
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
  
  def create_basic_crops_without_ai_data
    say_with_time "Creating basic US crops without AI data..." do
      # Simplified crops without detailed stage information
      basic_crops = [
        { name: 'Corn', variety: 'Field Corn', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 800.0 },
        { name: 'Soybeans', variety: 'Standard', groups: ['Fabaceae'], area_per_unit: 1.0, revenue_per_area: 600.0 },
        { name: 'Wheat', variety: 'Winter Wheat', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 500.0 },
        { name: 'Cotton', variety: 'Upland Cotton', groups: ['Malvaceae'], area_per_unit: 1.0, revenue_per_area: 900.0 },
        { name: 'Rice', variety: 'Long Grain', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 1000.0 }
      ]
      
      basic_crops.each do |crop_data|
        TempCrop.find_or_create_by!(
          name: crop_data[:name],
          variety: crop_data[:variety],
          is_reference: true,
          region: 'us'
        ) do |c|
          c.user_id = nil
          c.groups = crop_data[:groups].to_json
          c.area_per_unit = crop_data[:area_per_unit]
          c.revenue_per_area = crop_data[:revenue_per_area]
        end
      end
      
      basic_crops.size
    end
  end
  
  def seed_interaction_rules
    say_with_time "Creating interaction rules for US..." do
      unique_families = TempCrop.where(is_reference: true, region: 'us')
                               .pluck(:groups)
                               .map { |g| JSON.parse(g) }
                               .flatten
                               .compact
                               .uniq
                               .sort
      
      continuous_cultivation_impacts = {
        "Solanaceae" => { impact_ratio: 0.6, description: "Solanaceae continuous cultivation (Very Strong, 40% revenue decrease) - Tomatoes, Potatoes, Peppers, etc." },
        "Cucurbitaceae" => { impact_ratio: 0.65, description: "Cucurbitaceae continuous cultivation (Very Strong, 35% revenue decrease) - Cucumbers, Watermelon, etc." },
        "Brassicaceae" => { impact_ratio: 0.75, description: "Brassicaceae continuous cultivation (Strong, 25% revenue decrease) - Cabbage, Broccoli, etc." },
        "Asteraceae" => { impact_ratio: 0.75, description: "Asteraceae continuous cultivation (Strong, 25% revenue decrease) - Lettuce, etc." },
        "Apiaceae" => { impact_ratio: 0.8, description: "Apiaceae continuous cultivation (Moderate, 20% revenue decrease) - Carrots, etc." },
        "Amaryllidaceae" => { impact_ratio: 0.85, description: "Amaryllidaceae continuous cultivation (Mild, 15% revenue decrease) - Onions, etc." },
        "Amaranthaceae" => { impact_ratio: 0.9, description: "Amaranthaceae continuous cultivation (Mild, 10% revenue decrease) - Sugar Beets, etc." },
        "Poaceae" => { impact_ratio: 0.95, description: "Poaceae continuous cultivation (Almost None, 5% revenue decrease) - Corn, Wheat, Rice, Oats, etc." },
        "Fabaceae" => { impact_ratio: 0.9, description: "Fabaceae continuous cultivation (Mild, 10% revenue decrease) - Soybeans, Peanuts, etc." }
      }
      
      count = 0
      unique_families.each do |family|
        impact = continuous_cultivation_impacts[family] || {
          impact_ratio: 0.8,
          description: "#{family} continuous cultivation (Moderate, 20% revenue decrease)"
        }
        
        rule = TempInteractionRule.find_or_initialize_by(
          rule_type: 'continuous_cultivation',
          source_group: family,
          target_group: family,
          region: 'us'
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
