# frozen_string_literal: true

# US Region Seeds - Farms, Crops, and Interaction Rules

puts "🌱 Seeding US region data..."

# Reference Farms for US (50 major agricultural regions)
puts "Creating reference farms for US (region: us)..."

# Check if weather fixture file exists
weather_fixture_path = Rails.root.join('db/fixtures/us_reference_weather.json')

if weather_fixture_path.exist?
  # Fixture file exists, load weather data
  puts "✅ Loading US reference weather data from fixture..."
  weather_fixture = JSON.parse(File.read(weather_fixture_path))
  
  weather_fixture.each do |farm_name, farm_data|
    # Create farm
    farm = Farm.find_or_create_by!(name: farm_name, is_reference: true, region: 'us') do |f|
      f.user = User.anonymous_user
      f.latitude = farm_data['latitude']
      f.longitude = farm_data['longitude']
    end
    
    # Update existing records
    farm.update_column(:region, 'us') if farm.region != 'us'
    
    # Create WeatherLocation
    if farm_data['weather_location']
      wl_data = farm_data['weather_location']
      weather_location = WeatherLocation.find_or_create_by!(
        latitude: wl_data['latitude'],
        longitude: wl_data['longitude']
      ) do |wl|
        wl.elevation = wl_data['elevation']
        # NOAA-FTP doesn't provide timezone, use America/New_York as default for US
        wl.timezone = wl_data['timezone'] || 'America/New_York'
      end
      
      # Associate farm with weather_location
      unless farm.weather_location_id == weather_location.id
        farm.update_column(:weather_location_id, weather_location.id)
      end
      
      # Bulk insert WeatherData
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
        
        # Update progress info
        total_blocks = ((Date.today.year - 2000 + 1) / 5.0).ceil
        farm.update_columns(
          weather_data_status: 'completed',
          weather_data_fetched_years: total_blocks,
          weather_data_total_years: total_blocks
        )
      end
    end
  end
  
  puts "✅ Created #{Farm.where(is_reference: true, region: 'us').count} US reference farms with weather data"
  weather_location_ids = Farm.where(is_reference: true, region: 'us').pluck(:weather_location_id).compact.uniq
  total_weather_records = WeatherDatum.where(weather_location_id: weather_location_ids).count
  puts "   Total weather records: #{total_weather_records}"
  
else
  # Fixture file doesn't exist, create basic information only
  puts "⚠️  US weather fixture not found at #{weather_fixture_path}"
  puts "   Run 'bin/fetch_us_reference_weather_data' to generate fixture."
  puts "   Creating farms with basic information only..."
  
us_reference_farms = [
  # California - Major agricultural state
  { name: 'Kern County, CA', latitude: 35.3733, longitude: -119.0187 },
  { name: 'Fresno County, CA', latitude: 36.7378, longitude: -119.7871 },
  { name: 'Tulare County, CA', latitude: 36.2079, longitude: -118.7903 },
  { name: 'Monterey County, CA', latitude: 36.6002, longitude: -121.8947 },
  { name: 'Merced County, CA', latitude: 37.3022, longitude: -120.4830 },
  
  # Iowa - Corn Belt
  { name: 'Black Hawk County, IA', latitude: 42.4699, longitude: -92.3099 },
  { name: 'Linn County, IA', latitude: 42.0783, longitude: -91.5985 },
  { name: 'Scott County, IA', latitude: 41.6105, longitude: -90.6468 },
  { name: 'Polk County, IA', latitude: 41.6764, longitude: -93.5639 },
  { name: 'Johnson County, IA', latitude: 41.6611, longitude: -91.5302 },
  
  # Illinois - Corn and Soybean Belt
  { name: 'McLean County, IL', latitude: 40.4842, longitude: -88.9937 },
  { name: 'Champaign County, IL', latitude: 40.1164, longitude: -88.2434 },
  { name: 'LaSalle County, IL', latitude: 41.3433, longitude: -88.8617 },
  { name: 'Will County, IL', latitude: 41.4459, longitude: -88.0373 },
  { name: 'Adams County, IL', latitude: 40.0005, longitude: -91.1878 },
  
  # Nebraska - Corn and Cattle
  { name: 'Lancaster County, NE', latitude: 40.7989, longitude: -96.6804 },
  { name: 'Douglas County, NE', latitude: 41.2587, longitude: -96.1253 },
  { name: 'Sarpy County, NE', latitude: 41.1167, longitude: -96.0503 },
  { name: 'Hall County, NE', latitude: 40.8708, longitude: -98.3420 },
  { name: 'Buffalo County, NE', latitude: 40.6572, longitude: -99.0634 },
  
  # Minnesota - Dairy and Corn
  { name: 'Stearns County, MN', latitude: 45.5580, longitude: -94.6208 },
  { name: 'Wright County, MN', latitude: 45.1752, longitude: -93.9658 },
  { name: 'Olmsted County, MN', latitude: 43.9793, longitude: -92.4638 },
  { name: 'Blue Earth County, MN', latitude: 44.0541, longitude: -94.0719 },
  { name: 'Rice County, MN', latitude: 44.3483, longitude: -93.3111 },
  
  # Texas - Cattle and Cotton
  { name: 'Harris County, TX', latitude: 29.8582, longitude: -95.3935 },
  { name: 'Dallas County, TX', latitude: 32.7767, longitude: -96.7970 },
  { name: 'Tarrant County, TX', latitude: 32.7555, longitude: -97.3308 },
  { name: 'Bexar County, TX', latitude: 29.4241, longitude: -98.4936 },
  { name: 'Travis County, TX', latitude: 30.2672, longitude: -97.7431 },
  
  # Kansas - Wheat
  { name: 'Sedgwick County, KS', latitude: 37.6872, longitude: -97.3301 },
  { name: 'Johnson County, KS', latitude: 38.8403, longitude: -94.8160 },
  { name: 'Shawnee County, KS', latitude: 39.0558, longitude: -95.7129 },
  { name: 'Wyandotte County, KS', latitude: 39.1147, longitude: -94.6275 },
  { name: 'Douglas County, KS', latitude: 38.9717, longitude: -95.2353 },
  
  # North Dakota - Wheat and Soybeans
  { name: 'Cass County, ND', latitude: 46.8772, longitude: -97.0328 },
  { name: 'Burleigh County, ND', latitude: 46.8083, longitude: -100.7837 },
  { name: 'Grand Forks County, ND', latitude: 47.9253, longitude: -97.0329 },
  { name: 'Ward County, ND', latitude: 48.2330, longitude: -101.2955 },
  { name: 'Williams County, ND', latitude: 48.3308, longitude: -103.4244 },
  
  # South Dakota - Corn and Cattle
  { name: 'Minnehaha County, SD', latitude: 43.6911, longitude: -96.7092 },
  { name: 'Pennington County, SD', latitude: 43.9950, longitude: -102.7618 },
  { name: 'Lincoln County, SD', latitude: 43.3547, longitude: -96.6656 },
  { name: 'Brown County, SD', latitude: 45.4397, longitude: -98.4865 },
  { name: 'Brookings County, SD', latitude: 44.3114, longitude: -96.7984 },
  
  # Wisconsin - Dairy
  { name: 'Dane County, WI', latitude: 43.0731, longitude: -89.4012 },
  { name: 'Milwaukee County, WI', latitude: 43.0389, longitude: -87.9065 },
  { name: 'Waukesha County, WI', latitude: 43.0167, longitude: -88.2287 },
  { name: 'Brown County, WI', latitude: 44.5133, longitude: -88.0133 },
  { name: 'Racine County, WI', latitude: 42.7261, longitude: -87.7829 }
]

  us_reference_farms.each do |farm_data|
    farm = Farm.find_or_create_by!(name: farm_data[:name], is_reference: true, region: 'us') do |f|
      f.user = User.anonymous_user
      f.latitude = farm_data[:latitude]
      f.longitude = farm_data[:longitude]
    end
    
    # Update existing records if needed
    unless farm.region == 'us'
      farm.update_column(:region, 'us')
    end
  end

  puts "✅ Created #{Farm.where(is_reference: true, region: 'us').count} US reference farms (basic info only)"
end

# Reference Crops for US (30 major crops)
puts "Creating reference crops for US (region: us)..."

# Check if fixture file exists
crop_fixture_path = Rails.root.join('db/fixtures/us_reference_crops.json')

if crop_fixture_path.exist?
  # Fixture file exists, load AI information from it
  puts "✅ Loading US reference crop data from fixture..."
  crop_fixture = JSON.parse(File.read(crop_fixture_path))
  
  crop_fixture.each do |crop_name, crop_data|
    crop = Crop.find_or_create_by!(name: crop_name, variety: crop_data['variety'], is_reference: true, region: 'us') do |c|
      c.user_id = nil
      c.groups = crop_data['groups']
      c.area_per_unit = crop_data['area_per_unit']
      c.revenue_per_area = crop_data['revenue_per_area']
    end
    
    # Update existing records
    crop.update!(
      groups: crop_data['groups'],
      area_per_unit: crop_data['area_per_unit'],
      revenue_per_area: crop_data['revenue_per_area'],
      region: 'us'
    )
    
    # Delete existing stages and recreate
    crop.crop_stages.destroy_all
    
    # Create CropStages
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
            sterility_risk_threshold: temp_req['sterility_risk_threshold'],
            max_temperature: temp_req['max_temperature']
          )
        else
          stage.create_temperature_requirement!(
            base_temperature: temp_req['base_temperature'],
            optimal_min: temp_req['optimal_min'],
            optimal_max: temp_req['optimal_max'],
            low_stress_threshold: temp_req['low_stress_threshold'],
            high_stress_threshold: temp_req['high_stress_threshold'],
            frost_threshold: temp_req['frost_threshold'],
            sterility_risk_threshold: temp_req['sterility_risk_threshold'],
            max_temperature: temp_req['max_temperature']
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
  
  puts "✅ Created #{Crop.where(is_reference: true, region: 'us').count} US reference crops with AI data"
  puts "   Total crop stages: #{CropStage.joins(:crop).where(crops: { is_reference: true, region: 'us' }).count}"
  
else
  # Fixture file doesn't exist, create basic information only
  puts "⚠️  US crop fixture not found at #{crop_fixture_path}"
  puts "   Run 'bin/fetch_us_crops_with_agrr' and 'bin/translate_us_crop_stages' to generate fixture."
  puts "   Creating crops with basic information only..."
  
us_reference_crops = [
  {
    name: 'Corn',
    variety: 'Field Corn',
    groups: ['Poaceae'],
    area_per_unit: 1.0,
    revenue_per_area: 800.0,
    crop_stages: [
      {
        name: 'Planting',
        order: 1,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 15.0,
          optimal_max: 30.0,
          low_stress_threshold: 10.0,
          high_stress_threshold: 35.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1200.0
        }
      },
      {
        name: 'Vegetative Growth',
        order: 2,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 20.0,
          optimal_max: 32.0,
          low_stress_threshold: 12.0,
          high_stress_threshold: 35.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1400.0
        }
      },
      {
        name: 'Reproductive Growth',
        order: 3,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 20.0,
          optimal_max: 30.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 33.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1500.0
        }
      },
      {
        name: 'Harvest',
        order: 4,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 15.0,
          optimal_max: 28.0,
          low_stress_threshold: 10.0,
          high_stress_threshold: 32.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 38.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1000.0
        }
      }
    ]
  },
  {
    name: 'Soybeans',
    variety: 'Standard',
    groups: ['Fabaceae'],
    area_per_unit: 1.0,
    revenue_per_area: 600.0,
    crop_stages: [
      {
        name: 'Planting',
        order: 1,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 18.0,
          optimal_max: 30.0,
          low_stress_threshold: 10.0,
          high_stress_threshold: 35.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1000.0
        }
      },
      {
        name: 'Vegetative Growth',
        order: 2,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 22.0,
          optimal_max: 30.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 35.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1200.0
        }
      },
      {
        name: 'Reproductive Growth',
        order: 3,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 20.0,
          optimal_max: 28.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 32.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 38.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1300.0
        }
      },
      {
        name: 'Harvest',
        order: 4,
        temperature_requirement: {
          base_temperature: 10.0,
          optimal_min: 15.0,
          optimal_max: 25.0,
          low_stress_threshold: 10.0,
          high_stress_threshold: 30.0,
          frost_threshold: -2.0,
          sterility_risk_threshold: 32.0,
          max_temperature: 35.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 900.0
        }
      }
    ]
  },
  {
    name: 'Wheat',
    variety: 'Winter Wheat',
    groups: ['Poaceae'],
    area_per_unit: 1.0,
    revenue_per_area: 500.0,
    crop_stages: [
      {
        name: 'Planting',
        order: 1,
        temperature_requirement: {
          base_temperature: 0.0,
          optimal_min: 10.0,
          optimal_max: 24.0,
          low_stress_threshold: 0.0,
          high_stress_threshold: 30.0,
          frost_threshold: -10.0,
          sterility_risk_threshold: 32.0,
          max_temperature: 35.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 5.0,
          target_sunshine_hours: 8.0
        },
        thermal_requirement: {
          required_gdd: 800.0
        }
      },
      {
        name: 'Vegetative Growth',
        order: 2,
        temperature_requirement: {
          base_temperature: 0.0,
          optimal_min: 12.0,
          optimal_max: 25.0,
          low_stress_threshold: 0.0,
          high_stress_threshold: 30.0,
          frost_threshold: -10.0,
          sterility_risk_threshold: 33.0,
          max_temperature: 38.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1000.0
        }
      },
      {
        name: 'Reproductive Growth',
        order: 3,
        temperature_requirement: {
          base_temperature: 0.0,
          optimal_min: 15.0,
          optimal_max: 25.0,
          low_stress_threshold: 5.0,
          high_stress_threshold: 30.0,
          frost_threshold: -5.0,
          sterility_risk_threshold: 32.0,
          max_temperature: 35.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1100.0
        }
      },
      {
        name: 'Harvest',
        order: 4,
        temperature_requirement: {
          base_temperature: 0.0,
          optimal_min: 15.0,
          optimal_max: 30.0,
          low_stress_threshold: 10.0,
          high_stress_threshold: 35.0,
          frost_threshold: -5.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 900.0
        }
      }
    ]
  },
  {
    name: 'Cotton',
    variety: 'Upland Cotton',
    groups: ['Malvaceae'],
    area_per_unit: 1.0,
    revenue_per_area: 900.0,
    crop_stages: [
      {
        name: 'Planting',
        order: 1,
        temperature_requirement: {
          base_temperature: 15.0,
          optimal_min: 20.0,
          optimal_max: 32.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1500.0
        }
      },
      {
        name: 'Vegetative Growth',
        order: 2,
        temperature_requirement: {
          base_temperature: 15.0,
          optimal_min: 25.0,
          optimal_max: 35.0,
          low_stress_threshold: 18.0,
          high_stress_threshold: 38.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 40.0,
          max_temperature: 45.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 10.0,
          target_sunshine_hours: 14.0
        },
        thermal_requirement: {
          required_gdd: 1800.0
        }
      },
      {
        name: 'Reproductive Growth',
        order: 3,
        temperature_requirement: {
          base_temperature: 15.0,
          optimal_min: 22.0,
          optimal_max: 32.0,
          low_stress_threshold: 18.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 10.0,
          target_sunshine_hours: 14.0
        },
        thermal_requirement: {
          required_gdd: 2000.0
        }
      },
      {
        name: 'Harvest',
        order: 4,
        temperature_requirement: {
          base_temperature: 15.0,
          optimal_min: 20.0,
          optimal_max: 30.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1500.0
        }
      }
    ]
  },
  {
    name: 'Rice',
    variety: 'Long Grain',
    groups: ['Poaceae'],
    area_per_unit: 1.0,
    revenue_per_area: 1000.0,
    crop_stages: [
      {
        name: 'Planting',
        order: 1,
        temperature_requirement: {
          base_temperature: 12.0,
          optimal_min: 20.0,
          optimal_max: 32.0,
          low_stress_threshold: 12.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1200.0
        }
      },
      {
        name: 'Vegetative Growth',
        order: 2,
        temperature_requirement: {
          base_temperature: 12.0,
          optimal_min: 22.0,
          optimal_max: 32.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 38.0,
          max_temperature: 42.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1400.0
        }
      },
      {
        name: 'Reproductive Growth',
        order: 3,
        temperature_requirement: {
          base_temperature: 12.0,
          optimal_min: 22.0,
          optimal_max: 30.0,
          low_stress_threshold: 18.0,
          high_stress_threshold: 33.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 38.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 8.0,
          target_sunshine_hours: 12.0
        },
        thermal_requirement: {
          required_gdd: 1500.0
        }
      },
      {
        name: 'Harvest',
        order: 4,
        temperature_requirement: {
          base_temperature: 12.0,
          optimal_min: 20.0,
          optimal_max: 30.0,
          low_stress_threshold: 15.0,
          high_stress_threshold: 35.0,
          frost_threshold: 0.0,
          sterility_risk_threshold: 35.0,
          max_temperature: 40.0
        },
        sunshine_requirement: {
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 10.0
        },
        thermal_requirement: {
          required_gdd: 1000.0
        }
      }
    ]
  },
  # Additional crops with simplified data
  { name: 'Oats', variety: 'Standard', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 400.0 },
  { name: 'Barley', variety: 'Standard', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 450.0 },
  { name: 'Sorghum', variety: 'Grain', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 550.0 },
  { name: 'Rye', variety: 'Standard', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 400.0 },
  { name: 'Peanuts', variety: 'Runner', groups: ['Fabaceae'], area_per_unit: 0.5, revenue_per_area: 1200.0 },
  { name: 'Sugar Beets', variety: 'Standard', groups: ['Amaranthaceae'], area_per_unit: 0.5, revenue_per_area: 1500.0 },
  { name: 'Sugarcane', variety: 'Standard', groups: ['Poaceae'], area_per_unit: 1.0, revenue_per_area: 1800.0 },
  { name: 'Potatoes', variety: 'Russet', groups: ['Solanaceae'], area_per_unit: 0.3, revenue_per_area: 2000.0 },
  { name: 'Tomatoes', variety: 'Processing', groups: ['Solanaceae'], area_per_unit: 0.2, revenue_per_area: 2500.0 },
  { name: 'Lettuce', variety: 'Iceberg', groups: ['Asteraceae'], area_per_unit: 0.2, revenue_per_area: 1800.0 },
  { name: 'Broccoli', variety: 'Standard', groups: ['Brassicaceae'], area_per_unit: 0.3, revenue_per_area: 2000.0 },
  { name: 'Cabbage', variety: 'Green', groups: ['Brassicaceae'], area_per_unit: 0.3, revenue_per_area: 1500.0 },
  { name: 'Carrots', variety: 'Standard', groups: ['Apiaceae'], area_per_unit: 0.2, revenue_per_area: 1600.0 },
  { name: 'Onions', variety: 'Yellow', groups: ['Amaryllidaceae'], area_per_unit: 0.3, revenue_per_area: 1400.0 },
  { name: 'Apples', variety: 'Red Delicious', groups: ['Rosaceae'], area_per_unit: 0.1, revenue_per_area: 3000.0 },
  { name: 'Oranges', variety: 'Valencia', groups: ['Rutaceae'], area_per_unit: 0.1, revenue_per_area: 3500.0 },
  { name: 'Grapes', variety: 'Wine', groups: ['Vitaceae'], area_per_unit: 0.1, revenue_per_area: 4000.0 },
  { name: 'Strawberries', variety: 'June-bearing', groups: ['Rosaceae'], area_per_unit: 0.1, revenue_per_area: 5000.0 },
  { name: 'Blueberries', variety: 'Highbush', groups: ['Ericaceae'], area_per_unit: 0.1, revenue_per_area: 4500.0 },
  { name: 'Almonds', variety: 'Nonpareil', groups: ['Rosaceae'], area_per_unit: 0.1, revenue_per_area: 4000.0 },
  { name: 'Pistachios', variety: 'Kerman', groups: ['Anacardiaceae'], area_per_unit: 0.1, revenue_per_area: 4500.0 },
  { name: 'Walnuts', variety: 'Chandler', groups: ['Juglandaceae'], area_per_unit: 0.1, revenue_per_area: 3800.0 },
  { name: 'Bell Peppers', variety: 'Green', groups: ['Solanaceae'], area_per_unit: 0.2, revenue_per_area: 2200.0 },
  { name: 'Cucumbers', variety: 'Slicing', groups: ['Cucurbitaceae'], area_per_unit: 0.3, revenue_per_area: 1800.0 },
  { name: 'Watermelon', variety: 'Seedless', groups: ['Cucurbitaceae'], area_per_unit: 0.5, revenue_per_area: 1600.0 }
]

us_reference_crops.each do |crop_data|
  crop = Crop.find_or_create_by!(
    name: crop_data[:name],
    variety: crop_data[:variety],
    is_reference: true,
    region: 'us'
  ) do |c|
    c.user_id = nil
    c.groups = crop_data[:groups]
    c.area_per_unit = crop_data[:area_per_unit]
    c.revenue_per_area = crop_data[:revenue_per_area]
  end
  
  # Update existing records if needed
  crop.update!(
    groups: crop_data[:groups],
    area_per_unit: crop_data[:area_per_unit],
    revenue_per_area: crop_data[:revenue_per_area],
    region: 'us'
  )
  
  # Create crop stages if provided
  if crop_data[:crop_stages]
    crop_data[:crop_stages].each do |stage_data|
      stage = crop.crop_stages.find_or_create_by!(order: stage_data[:order]) do |s|
        s.name = stage_data[:name]
      end
      
      # Temperature Requirement
      if stage_data[:temperature_requirement]
        temp_req = stage_data[:temperature_requirement]
        if stage.temperature_requirement
          stage.temperature_requirement.update!(
            base_temperature: temp_req[:base_temperature],
            optimal_min: temp_req[:optimal_min],
            optimal_max: temp_req[:optimal_max],
            low_stress_threshold: temp_req[:low_stress_threshold],
            high_stress_threshold: temp_req[:high_stress_threshold],
            frost_threshold: temp_req[:frost_threshold],
            sterility_risk_threshold: temp_req[:sterility_risk_threshold],
            max_temperature: temp_req[:max_temperature]
          )
        else
          stage.create_temperature_requirement!(
            base_temperature: temp_req[:base_temperature],
            optimal_min: temp_req[:optimal_min],
            optimal_max: temp_req[:optimal_max],
            low_stress_threshold: temp_req[:low_stress_threshold],
            high_stress_threshold: temp_req[:high_stress_threshold],
            frost_threshold: temp_req[:frost_threshold],
            sterility_risk_threshold: temp_req[:sterility_risk_threshold],
            max_temperature: temp_req[:max_temperature]
          )
        end
      end
      
      # Sunshine Requirement
      if stage_data[:sunshine_requirement]
        sun_req = stage_data[:sunshine_requirement]
        if stage.sunshine_requirement
          stage.sunshine_requirement.update!(
            minimum_sunshine_hours: sun_req[:minimum_sunshine_hours],
            target_sunshine_hours: sun_req[:target_sunshine_hours]
          )
        else
          stage.create_sunshine_requirement!(
            minimum_sunshine_hours: sun_req[:minimum_sunshine_hours],
            target_sunshine_hours: sun_req[:target_sunshine_hours]
          )
        end
      end
      
      # Thermal Requirement
      if stage_data[:thermal_requirement]
        thermal_req = stage_data[:thermal_requirement]
        if stage.thermal_requirement
          stage.thermal_requirement.update!(
            required_gdd: thermal_req[:required_gdd]
          )
        else
          stage.create_thermal_requirement!(
            required_gdd: thermal_req[:required_gdd]
          )
        end
      end
    end
  end
end

  puts "✅ Created #{Crop.where(is_reference: true, region: 'us').count} US reference crops (basic info only)"
end

# Interaction Rules for US (translated from Japanese)
puts "Creating interaction rules for US (region: us)..."

# Extract unique families from US reference crops
unique_families = Crop.where(is_reference: true, region: 'us').pluck(:groups).flatten.compact.uniq.sort

# Continuous cultivation impacts (based on general agricultural knowledge)
# impact_ratio: less than 1.0 means revenue decrease, lower values indicate stronger impact
continuous_cultivation_impacts = {
  "Solanaceae" => {
    impact_ratio: 0.6,
    description: "Solanaceae continuous cultivation (Very Strong, 40% revenue decrease) - Tomatoes, Potatoes, Peppers, etc."
  },
  "Cucurbitaceae" => {
    impact_ratio: 0.65,
    description: "Cucurbitaceae continuous cultivation (Very Strong, 35% revenue decrease) - Cucumbers, Watermelon, etc."
  },
  "Brassicaceae" => {
    impact_ratio: 0.75,
    description: "Brassicaceae continuous cultivation (Strong, 25% revenue decrease) - Cabbage, Broccoli, etc."
  },
  "Asteraceae" => {
    impact_ratio: 0.75,
    description: "Asteraceae continuous cultivation (Strong, 25% revenue decrease) - Lettuce, etc."
  },
  "Apiaceae" => {
    impact_ratio: 0.8,
    description: "Apiaceae continuous cultivation (Moderate, 20% revenue decrease) - Carrots, etc."
  },
  "Amaryllidaceae" => {
    impact_ratio: 0.85,
    description: "Amaryllidaceae continuous cultivation (Mild, 15% revenue decrease) - Onions, etc."
  },
  "Amaranthaceae" => {
    impact_ratio: 0.9,
    description: "Amaranthaceae continuous cultivation (Mild, 10% revenue decrease) - Sugar Beets, etc."
  },
  "Poaceae" => {
    impact_ratio: 0.95,
    description: "Poaceae continuous cultivation (Almost None, 5% revenue decrease) - Corn, Wheat, Rice, Oats, etc."
  },
  "Fabaceae" => {
    impact_ratio: 0.9,
    description: "Fabaceae continuous cultivation (Mild, 10% revenue decrease) - Soybeans, Peanuts, etc."
  }
}

# Create interaction rules for existing families
interaction_rules_data = []
unique_families.each do |family|
  if continuous_cultivation_impacts.key?(family)
    impact = continuous_cultivation_impacts[family]
    interaction_rules_data << {
      rule_type: "continuous_cultivation",
      source_group: family,
      target_group: family,
      impact_ratio: impact[:impact_ratio],
      is_directional: true,
      is_reference: true,
      description: impact[:description]
    }
  else
    # Undefined families are treated as moderate continuous cultivation impact
    interaction_rules_data << {
      rule_type: "continuous_cultivation",
      source_group: family,
      target_group: family,
      impact_ratio: 0.8,
      is_directional: true,
      is_reference: true,
      description: "#{family} continuous cultivation (Moderate, 20% revenue decrease)"
    }
  end
end

interaction_rules_data.each do |rule_data|
  rule = InteractionRule.find_or_create_by!(
    rule_type: rule_data[:rule_type],
    source_group: rule_data[:source_group],
    target_group: rule_data[:target_group],
    region: 'us'
  ) do |r|
    r.impact_ratio = rule_data[:impact_ratio]
    r.is_directional = rule_data[:is_directional]
    r.is_reference = rule_data[:is_reference]
    r.user_id = nil
    r.description = rule_data[:description]
  end
  
  # Update existing records if needed
  rule.update!(
    impact_ratio: rule_data[:impact_ratio],
    description: rule_data[:description],
    region: 'us'
  )
end

puts "✅ Created #{InteractionRule.where(region: 'us').count} US interaction rules"

puts "🎉 US region seeding completed!"
puts ""
puts "Summary:"
puts "  US Reference Farms: #{Farm.where(is_reference: true, region: 'us').count}"
puts "  US Reference Crops: #{Crop.where(is_reference: true, region: 'us').count}"
puts "  US Interaction Rules: #{InteractionRule.where(region: 'us').count}"

