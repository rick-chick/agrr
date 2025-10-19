# frozen_string_literal: true

class SeedIndiaReferenceData < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  
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
    has_many :crop_stages, class_name: 'SeedIndiaReferenceData::TempCropStage', foreign_key: 'crop_id'
  end
  
  class TempCropStage < ActiveRecord::Base
    self.table_name = 'crop_stages'
    belongs_to :crop, class_name: 'SeedIndiaReferenceData::TempCrop', foreign_key: 'crop_id'
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
    say "🌱 Seeding India (in) reference data..."
    
    # 1. Reference Farms + Weather Data
    seed_reference_farms_and_weather
    
    # 2. Reference Crops
    seed_reference_crops
    
    # 3. Interaction Rules
    seed_interaction_rules
    
    say "✅ India reference data seeding completed!"
  end
  
  def down
    say "🗑️  Removing India (in) reference data..."
    
    # 逆順で削除
    TempInteractionRule.where(region: 'in').delete_all
    
    # Crops関連
    in_crop_ids = TempCrop.where(region: 'in', is_reference: true).pluck(:id)
    in_crop_stage_ids = TempCropStage.where(crop_id: in_crop_ids).pluck(:id)
    
    TempSunshineRequirement.where(crop_stage_id: in_crop_stage_ids).delete_all
    TempThermalRequirement.where(crop_stage_id: in_crop_stage_ids).delete_all
    TempTemperatureRequirement.where(crop_stage_id: in_crop_stage_ids).delete_all
    TempCropStage.where(crop_id: in_crop_ids).delete_all
    TempCrop.where(region: 'in', is_reference: true).delete_all
    
    # Farms関連
    in_farm_ids = TempFarm.where(region: 'in', is_reference: true).pluck(:id)
    in_weather_location_ids = TempFarm.where(id: in_farm_ids).pluck(:weather_location_id).compact.uniq
    
    TempWeatherDatum.where(weather_location_id: in_weather_location_ids).delete_all
    TempWeatherLocation.where(id: in_weather_location_ids).delete_all
    TempFarm.where(region: 'in', is_reference: true).delete_all
    
    say "✅ India reference data removed"
  end
  
  private
  
  def seed_reference_farms_and_weather
    fixture_path = Rails.root.join('db/fixtures/india_reference_weather.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  India fixture not found: #{fixture_path}", true
      return create_basic_farms_without_weather
    end
    
    say_with_time "Loading India reference farms with weather data from fixture..." do
      weather_fixture = JSON.parse(File.read(fixture_path))
      count = 0
      
      weather_fixture.each do |farm_name, farm_data|
        anonymous_user = TempUser.find_by(is_anonymous: true)
        
        # Farm作成
        farm = TempFarm.find_or_initialize_by(name: farm_name, is_reference: true, region: 'in')
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
            wl.timezone = wl_data['timezone'] || 'Asia/Kolkata'
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
          end
        end
        
        count += 1
      end
      
      count
    end
  end
  
  def create_basic_farms_without_weather
    say_with_time "Creating basic India farms without weather data..." do
      reference_farms = [
        # North India (Wheat-Rice Belt) - उत्तर भारत (गेहूं-चावल क्षेत्र)
        { name: 'लुधियाना, पंजाब', latitude: 30.9010, longitude: 75.8573 },              # Ludhiana, Punjab
        { name: 'अमृतसर, पंजाब', latitude: 31.6340, longitude: 74.8723 },                # Amritsar, Punjab
        { name: 'जालंधर, पंजाब', latitude: 31.3260, longitude: 75.5762 },                # Jalandhar, Punjab
        { name: 'करनाल, हरियाणा', latitude: 29.6857, longitude: 76.9905 },              # Karnal, Haryana
        { name: 'हिसार, हरियाणा', latitude: 29.1492, longitude: 75.7217 },              # Hisar, Haryana
        { name: 'रोहतक, हरियाणा', latitude: 28.8955, longitude: 76.6066 },              # Rohtak, Haryana
        { name: 'मेरठ, उत्तर प्रदेश', latitude: 29.0176, longitude: 77.7065 },          # Meerut, Uttar Pradesh
        { name: 'लखनऊ, उत्तर प्रदेश', latitude: 26.8467, longitude: 80.9462 },          # Lucknow, Uttar Pradesh
        { name: 'कानपुर, उत्तर प्रदेश', latitude: 26.4499, longitude: 80.3319 },         # Kanpur, Uttar Pradesh
        { name: 'गोरखपुर, उत्तर प्रदेश', latitude: 26.7606, longitude: 83.3732 },        # Gorakhpur, Uttar Pradesh
        { name: 'वाराणसी, उत्तर प्रदेश', latitude: 25.3176, longitude: 82.9739 },        # Varanasi, Uttar Pradesh
        
        # East India (Rice-Jute) - पूर्व भारत (चावल-जूट)
        { name: 'पटना, बिहार', latitude: 25.5941, longitude: 85.1376 },                 # Patna, Bihar
        { name: 'मुजफ्फरपुर, बिहार', latitude: 26.1225, longitude: 85.3906 },           # Muzaffarpur, Bihar
        { name: 'कोलकाता, पश्चिम बंगाल', latitude: 22.5726, longitude: 88.3639 },       # Kolkata, West Bengal
        { name: 'बर्धमान, पश्चिम बंगाल', latitude: 23.2324, longitude: 87.8615 },        # Bardhaman, West Bengal
        { name: 'भुवनेश्वर, ओडिशा', latitude: 20.2961, longitude: 85.8245 },            # Bhubaneswar, Odisha
        { name: 'कटक, ओडिशा', latitude: 20.4625, longitude: 85.8830 },                 # Cuttack, Odisha
        { name: 'गुवाहाटी, असम', latitude: 26.1445, longitude: 91.7362 },               # Guwahati, Assam
        { name: 'रायपुर, छत्तीसगढ़', latitude: 21.2514, longitude: 81.6296 },           # Raipur, Chhattisgarh
        
        # West India (Cotton-Groundnut) - पश्चिम भारत (कपास-मूंगफली)
        { name: 'नागपुर, महाराष्ट्र', latitude: 21.1458, longitude: 79.0882 },          # Nagpur, Maharashtra
        { name: 'नासिक, महाराष्ट्र', latitude: 19.9975, longitude: 73.7898 },           # Nashik, Maharashtra
        { name: 'औरंगाबाद, महाराष्ट्र', latitude: 19.8762, longitude: 75.3433 },         # Aurangabad, Maharashtra
        { name: 'अहमदनगर, महाराष्ट्र', latitude: 19.0948, longitude: 74.7480 },         # Ahmednagar, Maharashtra
        { name: 'अहमदाबाद, गुजरात', latitude: 23.0225, longitude: 72.5714 },            # Ahmedabad, Gujarat
        { name: 'सूरत, गुजरात', latitude: 21.1702, longitude: 72.8311 },                # Surat, Gujarat
        { name: 'राजकोट, गुजरात', latitude: 22.3039, longitude: 70.8022 },              # Rajkot, Gujarat
        { name: 'वडोदरा, गुजरात', latitude: 22.3072, longitude: 73.1812 },              # Vadodara, Gujarat
        { name: 'जयपुर, राजस्थान', latitude: 26.9124, longitude: 75.7873 },             # Jaipur, Rajasthan
        { name: 'जोधपुर, राजस्थान', latitude: 26.2389, longitude: 73.0243 },            # Jodhpur, Rajasthan
        { name: 'कोटा, राजस्थान', latitude: 25.2138, longitude: 75.8648 },              # Kota, Rajasthan
        
        # Central India (Soybean-Wheat) - मध्य भारत (सोयाबीन-गेहूं)
        { name: 'इंदौर, मध्य प्रदेश', latitude: 22.7196, longitude: 75.8577 },          # Indore, Madhya Pradesh
        { name: 'भोपाल, मध्य प्रदेश', latitude: 23.2599, longitude: 77.4126 },          # Bhopal, Madhya Pradesh
        { name: 'जबलपुर, मध्य प्रदेश', latitude: 23.1815, longitude: 79.9864 },         # Jabalpur, Madhya Pradesh
        { name: 'ग्वालियर, मध्य प्रदेश', latitude: 26.2183, longitude: 78.1828 },       # Gwalior, Madhya Pradesh
        
        # South India (Rice-Spices) - दक्षिण भारत (चावल-मसाले)
        { name: 'हैदराबाद, तेलंगाना', latitude: 17.3850, longitude: 78.4867 },          # Hyderabad, Telangana
        { name: 'वारंगल, तेलंगाना', latitude: 17.9784, longitude: 79.6005 },            # Warangal, Telangana
        { name: 'विजयवाड़ा, आंध्र प्रदेश', latitude: 16.5062, longitude: 80.6480 },     # Vijayawada, Andhra Pradesh
        { name: 'विशाखापट्टनम, आंध्र प्रदेश', latitude: 17.6868, longitude: 83.2185 },  # Visakhapatnam, Andhra Pradesh
        { name: 'गुंटूर, आंध्र प्रदेश', latitude: 16.3067, longitude: 80.4365 },        # Guntur, Andhra Pradesh
        { name: 'बेंगलुरु, कर्नाटक', latitude: 12.9716, longitude: 77.5946 },           # Bangalore, Karnataka
        { name: 'मैसूर, कर्नाटक', latitude: 12.2958, longitude: 76.6394 },              # Mysore, Karnataka
        { name: 'मैंगलोर, कर्नाटक', latitude: 12.9141, longitude: 74.8560 },            # Mangalore, Karnataka
        { name: 'हुबली, कर्नाटक', latitude: 15.3647, longitude: 75.1240 },              # Hubli, Karnataka
        { name: 'चेन्नई, तमिल नाडु', latitude: 13.0827, longitude: 80.2707 },           # Chennai, Tamil Nadu
        { name: 'मदुरै, तमिल नाडु', latitude: 9.9252, longitude: 78.1198 },             # Madurai, Tamil Nadu
        { name: 'कोयम्बटूर, तमिल नाडु', latitude: 11.0168, longitude: 76.9558 },        # Coimbatore, Tamil Nadu
        { name: 'तिरुचिरापल्ली, तमिल नाडु', latitude: 10.7905, longitude: 78.7047 },    # Tiruchirappalli, Tamil Nadu
        { name: 'सेलम, तमिल नाडु', latitude: 11.6643, longitude: 78.1460 },             # Salem, Tamil Nadu
        { name: 'कोच्चि, केरल', latitude: 9.9312, longitude: 76.2673 },                 # Kochi, Kerala
        { name: 'तिरुवनंतपुरम, केरल', latitude: 8.5241, longitude: 76.9366 }            # Trivandrum, Kerala
      ]
      
      anonymous_user = TempUser.find_by(is_anonymous: true)
      
      reference_farms.each do |farm_data|
        TempFarm.find_or_create_by!(name: farm_data[:name], is_reference: true, region: 'in') do |f|
          f.user_id = anonymous_user.id
          f.latitude = farm_data[:latitude]
          f.longitude = farm_data[:longitude]
        end
      end
      
      reference_farms.size
    end
  end
  
  def seed_reference_crops
    fixture_path = Rails.root.join('db/fixtures/india_reference_crops.json')
    
    unless File.exist?(fixture_path)
      say "⚠️  India crop fixture not found: #{fixture_path}", true
      return create_basic_crops_without_ai_data
    end
    
    say_with_time "Loading India reference crops from fixture..." do
      crop_fixture = JSON.parse(File.read(fixture_path))
      count = 0
      
      crop_fixture.each do |crop_name, crop_data|
        crop = TempCrop.find_or_initialize_by(name: crop_name, variety: crop_data['variety'], is_reference: true, region: 'in')
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
    say_with_time "Creating basic India crops without AI data..." do
      reference_crops = [
        { name: 'चावल', variety: 'बासमती', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 },      # Rice - Basmati
        { name: 'चावल', variety: 'IR64', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 7000.0 },          # Rice - IR64
        { name: 'गेहूं', variety: 'HD2967', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 6000.0 },       # Wheat
        { name: 'कपास', variety: 'बीटी कपास', groups: ['Malvaceae'], area_per_unit: 0.25, revenue_per_area: 12000.0 },  # Cotton - Bt Cotton
        { name: 'गन्ना', variety: 'CoC671', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 15000.0 },      # Sugarcane
        { name: 'सोयाबीन', variety: 'JS335', groups: ['Fabaceae'], area_per_unit: 0.25, revenue_per_area: 7000.0 },     # Soybeans
        { name: 'मूंगफली', variety: 'TMV2', groups: ['Fabaceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 },      # Groundnut
        { name: 'चना', variety: 'देसी', groups: ['Fabaceae'], area_per_unit: 0.25, revenue_per_area: 9000.0 },          # Chickpeas
        { name: 'मसूर', variety: 'मसूर दाल', groups: ['Fabaceae'], area_per_unit: 0.25, revenue_per_area: 8500.0 },     # Lentils
        { name: 'अरहर', variety: 'तूर दाल', groups: ['Fabaceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 },      # Pigeon Peas
        { name: 'मक्का', variety: 'संकर', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 7000.0 },        # Maize - Hybrid
        { name: 'बाजरा', variety: 'मोती बाजरा', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 5000.0 },   # Pearl Millet
        { name: 'ज्वार', variety: 'ज्वार अनाज', groups: ['Poaceae'], area_per_unit: 0.25, revenue_per_area: 5000.0 },  # Sorghum
        { name: 'सरसों', variety: 'पूसा बोल्ड', groups: ['Brassicaceae'], area_per_unit: 0.25, revenue_per_area: 7000.0 }, # Mustard
        { name: 'सूरजमुखी', variety: 'KBSH44', groups: ['Asteraceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 }, # Sunflower
        { name: 'जूट', variety: 'JRO524', groups: ['Malvaceae'], area_per_unit: 0.25, revenue_per_area: 6000.0 },       # Jute
        { name: 'मिर्च', variety: 'गुंटूर', groups: ['Solanaceae'], area_per_unit: 0.25, revenue_per_area: 15000.0 },   # Chili Peppers
        { name: 'टमाटर', variety: 'पूसा रूबी', groups: ['Solanaceae'], area_per_unit: 0.25, revenue_per_area: 12000.0 }, # Tomatoes
        { name: 'आलू', variety: 'कुफरी', groups: ['Solanaceae'], area_per_unit: 0.25, revenue_per_area: 10000.0 },      # Potatoes
        { name: 'प्याज', variety: 'नासिक लाल', groups: ['Amaryllidaceae'], area_per_unit: 0.25, revenue_per_area: 9000.0 }, # Onions
        { name: 'बैंगन', variety: 'बैंगन', groups: ['Solanaceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 },     # Eggplant
        { name: 'पत्ता गोभी', variety: 'गोल्डन एकर', groups: ['Brassicaceae'], area_per_unit: 0.25, revenue_per_area: 7000.0 }, # Cabbage
        { name: 'फूल गोभी', variety: 'स्नोबॉल', groups: ['Brassicaceae'], area_per_unit: 0.25, revenue_per_area: 8000.0 }, # Cauliflower
        { name: 'चाय', variety: 'असम', groups: ['Theaceae'], area_per_unit: 0.25, revenue_per_area: 20000.0 },         # Tea
        { name: 'कॉफी', variety: 'अरेबिका', groups: ['Rubiaceae'], area_per_unit: 0.25, revenue_per_area: 25000.0 },   # Coffee
        { name: 'हल्दी', variety: 'अल्लेप्पी', groups: ['Zingiberaceae'], area_per_unit: 0.25, revenue_per_area: 18000.0 }, # Turmeric
        { name: 'अदरक', variety: 'रियो', groups: ['Zingiberaceae'], area_per_unit: 0.25, revenue_per_area: 16000.0 },  # Ginger
        { name: 'इलायची', variety: 'मालाबार', groups: ['Zingiberaceae'], area_per_unit: 0.25, revenue_per_area: 30000.0 }, # Cardamom
        { name: 'नारियल', variety: 'लंबा', groups: ['Arecaceae'], area_per_unit: 0.25, revenue_per_area: 12000.0 },    # Coconut
        { name: 'आम', variety: 'अल्फांसो', groups: ['Anacardiaceae'], area_per_unit: 0.25, revenue_per_area: 20000.0 }  # Mangoes
      ]
      
      reference_crops.each do |crop_data|
        TempCrop.find_or_create_by!(
          name: crop_data[:name],
          variety: crop_data[:variety],
          is_reference: true,
          region: 'in'
        ) do |c|
          c.user_id = nil
          c.groups = crop_data[:groups].to_json
          c.area_per_unit = crop_data[:area_per_unit]
          c.revenue_per_area = crop_data[:revenue_per_area]
        end
      end
      
      reference_crops.size
    end
  end
  
  def seed_interaction_rules
    say_with_time "Creating interaction rules for India..." do
      # 参照作物のgroupsから科を抽出
      unique_families = TempCrop.where(is_reference: true, region: 'in')
                               .pluck(:groups)
                               .map { |g| JSON.parse(g) }
                               .flatten
                               .compact
                               .uniq
                               .sort
      
      # 連作の影響度（英語名で定義）
      continuous_cultivation_impacts = {
        "Solanaceae" => { impact_ratio: 0.6, description: "Solanaceae continuous cultivation (Very Strong, 40% revenue decrease)" },
        "Malvaceae" => { impact_ratio: 0.65, description: "Malvaceae continuous cultivation (Very Strong, 35% revenue decrease)" },
        "Brassicaceae" => { impact_ratio: 0.75, description: "Brassicaceae continuous cultivation (Strong, 25% revenue decrease)" },
        "Asteraceae" => { impact_ratio: 0.75, description: "Asteraceae continuous cultivation (Strong, 25% revenue decrease)" },
        "Zingiberaceae" => { impact_ratio: 0.7, description: "Zingiberaceae continuous cultivation (Strong, 30% revenue decrease)" },
        "Amaryllidaceae" => { impact_ratio: 0.8, description: "Amaryllidaceae continuous cultivation (Moderate, 20% revenue decrease)" },
        "Fabaceae" => { impact_ratio: 0.9, description: "Fabaceae continuous cultivation (Light, 10% revenue decrease)" },
        "Poaceae" => { impact_ratio: 0.95, description: "Poaceae continuous cultivation (Almost None, 5% revenue decrease)" },
        "Theaceae" => { impact_ratio: 0.9, description: "Theaceae continuous cultivation (Light, 10% revenue decrease)" },
        "Rubiaceae" => { impact_ratio: 0.85, description: "Rubiaceae continuous cultivation (Light, 15% revenue decrease)" },
        "Arecaceae" => { impact_ratio: 0.9, description: "Arecaceae continuous cultivation (Light, 10% revenue decrease)" },
        "Anacardiaceae" => { impact_ratio: 0.85, description: "Anacardiaceae continuous cultivation (Light, 15% revenue decrease)" }
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
          region: 'in'
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
