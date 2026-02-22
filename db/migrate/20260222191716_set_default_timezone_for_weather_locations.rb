class SetDefaultTimezoneForWeatherLocations < ActiveRecord::Migration[8.0]
  def up
    # Set default timezone 'UTC' for weather locations that have blank or null timezone
    WeatherLocation.where(timezone: [nil, '']).update_all(timezone: 'UTC')
  end

  def down
    # No-op: we don't want to revert timezone assignments
  end
end
