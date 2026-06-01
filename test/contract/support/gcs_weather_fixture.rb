# frozen_string_literal: true

# Shared GCS bulk fixture for CONTRACT_RUNTIME=rust (see scripts/run-rust-contract-tests.sh).
module GcsWeatherFixture
  def gcs_fixture_path(weather_location_id, year = Date.current.year)
    root = ENV.fetch("WEATHER_DATA_LOCAL_ROOT")
    File.join(root, "weather_data", weather_location_id.to_s, "#{year}.json")
  end

  def seed_rust_gcs_weather_fixture!(weather_location_id:, dates: nil)
    return unless ENV["WEATHER_DATA_STORAGE"] == "gcs"

    dates ||= [Date.current]
    by_year = dates.group_by(&:year)
    by_year.each do |year, year_dates|
      payload = year_dates.index_with do |_d|
        { "temperature_max" => 20.0, "temperature_min" => 10.0, "temperature_mean" => 15.0 }
      end.transform_keys(&:to_s)
      path = gcs_fixture_path(weather_location_id, year)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, payload.to_json)
    end
  end
end
