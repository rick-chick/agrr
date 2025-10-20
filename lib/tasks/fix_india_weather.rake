# frozen_string_literal: true

namespace :agrr do
  desc "Fix India weather data by loading from fixture"
  task fix_india_weather: :environment do
    puts "🌱 Adding weather data to India reference farms..."
    
    fixture_path = Rails.root.join('db/fixtures/india_reference_weather.json')
    
    unless File.exist?(fixture_path)
      puts "❌ Fixture file not found: #{fixture_path}"
      exit 1
    end
    
    weather_fixture = JSON.parse(File.read(fixture_path))
    
    updated_farms = 0
    created_locations = 0
    created_weather_records = 0
    
    weather_fixture.each do |farm_name, farm_data|
      # Find existing farm by coordinates (more reliable than name matching)
      farm = Farm.find_by(
        latitude: farm_data['latitude'].to_f.round(4),
        longitude: farm_data['longitude'].to_f.round(4),
        is_reference: true,
        region: 'in'
      )
      
      unless farm
        puts "⚠️  Farm not found for coordinates: #{farm_data['latitude']}, #{farm_data['longitude']} (#{farm_name})"
        next
      end
      
      # Skip if already has weather data
      if farm.weather_location_id.present?
        puts "✓ #{farm_name} already has weather data, skipping..."
        next
      end
      
      # Create WeatherLocation
      if farm_data['weather_location']
        wl_data = farm_data['weather_location']
        weather_location = WeatherLocation.find_or_create_by!(
          latitude: wl_data['latitude'],
          longitude: wl_data['longitude']
        ) do |wl|
          wl.elevation = wl_data['elevation']
          wl.timezone = wl_data['timezone'] || 'Asia/Kolkata'
        end
        
        created_locations += 1 if weather_location.previously_new_record?
        
        farm.update!(
          weather_location_id: weather_location.id,
          weather_data_status: 'completed'
        )
        
        # Insert WeatherData in bulk
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
          )
          
          created_weather_records += weather_records.size
          puts "✓ #{farm_name}: Added #{weather_records.size} weather records"
        end
        
        updated_farms += 1
      end
    end
    
    puts "\n✅ India weather data fix completed!"
    puts "  - Updated farms: #{updated_farms}"
    puts "  - Created weather locations: #{created_locations}"
    puts "  - Created weather records: #{created_weather_records}"
  end
end

