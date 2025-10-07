# frozen_string_literal: true

namespace :weather do
  desc "Fetch weather data calendar for all farms from 2000 to today"
  task fetch_calendar: :environment do
    start_date = Date.new(2000, 1, 1)
    end_date = Date.today

    puts "Fetching weather data calendar from #{start_date} to #{end_date}"
    puts "=" * 80

    # 全農場の緯度経度を取得
    farms = Farm.where.not(latitude: nil, longitude: nil).select(:latitude, :longitude).distinct

    if farms.empty?
      puts "No farms with coordinates found."
      exit 0
    end

    puts "Found #{farms.count} unique farm location(s)"
    
    # 各緯度経度ごとにジョブをキューに追加
    farms.each do |farm|
      # 年ごとに分割して取得（APIへの負荷を考慮）
      (2000..Date.today.year).each do |year|
        year_start = [Date.new(year, 1, 1), start_date].max
        year_end = [Date.new(year, 12, 31), end_date].min

        next if year_start > year_end

        puts "Queueing job for (#{farm.latitude}, #{farm.longitude}) - Year #{year}"
        
        FetchWeatherDataJob.perform_later(
          latitude: farm.latitude,
          longitude: farm.longitude,
          start_date: year_start,
          end_date: year_end
        )
      end
    end

    puts "=" * 80
    puts "All jobs queued successfully!"
    puts "Jobs will be processed by Solid Queue in the background."
  end

  desc "Fetch weather data for a specific farm"
  task :fetch_for_farm, [:farm_id, :start_date, :end_date] => :environment do |t, args|
    farm = Farm.find(args[:farm_id])
    
    unless farm.has_coordinates?
      puts "Farm #{farm.id} does not have coordinates."
      exit 1
    end

    start_date = args[:start_date] ? Date.parse(args[:start_date]) : Date.new(2000, 1, 1)
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.today

    puts "Fetching weather data for Farm ##{farm.id} (#{farm.name})"
    puts "Location: #{farm.latitude}, #{farm.longitude}"
    puts "Period: #{start_date} to #{end_date}"
    puts "=" * 80

    FetchWeatherDataJob.perform_later(
      latitude: farm.latitude,
      longitude: farm.longitude,
      start_date: start_date,
      end_date: end_date
    )

    puts "Job queued successfully!"
  end

  desc "Fetch weather data immediately (synchronous) for testing"
  task :fetch_now, [:latitude, :longitude, :start_date, :end_date] => :environment do |t, args|
    latitude = args[:latitude].to_f
    longitude = args[:longitude].to_f
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : Date.today - 7.days
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : Date.today

    puts "Fetching weather data immediately"
    puts "Location: #{latitude}, #{longitude}"
    puts "Period: #{start_date} to #{end_date}"
    puts "=" * 80

    FetchWeatherDataJob.perform_now(
      latitude: latitude,
      longitude: longitude,
      start_date: start_date,
      end_date: end_date
    )

    puts "=" * 80
    puts "Weather data fetched successfully!"
    
    # 結果を表示
    location = WeatherLocation.find_by(latitude: latitude, longitude: longitude)
    if location
      weather_data = location.weather_data_for_period(start_date, end_date)
      puts "\nFetched #{weather_data.count} records:"
      weather_data.each do |data|
        puts "  #{data.date}: #{data.temperature_min}°C - #{data.temperature_max}°C"
      end
    end
  end

  desc "Show weather data statistics"
  task stats: :environment do
    puts "Weather Data Statistics"
    puts "=" * 80
    puts "Weather Locations: #{WeatherLocation.count}"
    puts "Weather Data Records: #{WeatherDatum.count}"
    
    if WeatherLocation.any?
      puts "\nLocations:"
      WeatherLocation.includes(:weather_data).each do |location|
        puts "  #{location.coordinates_string}"
        puts "    Elevation: #{location.elevation}m"
        puts "    Timezone: #{location.timezone}"
        puts "    Records: #{location.weather_data.count}"
        if location.weather_data.any?
          puts "    Date Range: #{location.weather_data.minimum(:date)} - #{location.weather_data.maximum(:date)}"
        end
      end
    end
  end
end

