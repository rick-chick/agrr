# frozen_string_literal: true

require "test_helper"

class WeatherRakeTest < ActiveSupport::TestCase
  class InMemoryBucket
    def initialize
      @stored = {}
    end

    def file(path)
      return nil unless @stored.key?(path)

      content = @stored[path]
      blob = Object.new
      blob.define_singleton_method(:download) { content.is_a?(String) ? content : content.to_s }
      blob
    end

    def files(prefix:)
      prefix_s = prefix.to_s
      @stored.select { |path, _| path.start_with?(prefix_s) }.map do |path, content|
        blob = Object.new
        blob.define_singleton_method(:download) { content.is_a?(String) ? content : content.to_s }
        blob.define_singleton_method(:name) { path }
        blob
      end
    end

    def create_file(io, path, content_type: nil)
      content = io.respond_to?(:read) ? io.read : io.to_s
      @stored[path] = content
    end

    def stored_files
      @stored
    end
  end

  setup do
    Rails.application.load_tasks
    @bucket = InMemoryBucket.new
  end

  teardown do
    Rake::Task["weather:migrate_to_gcs"].reenable
  end

  test "migrate_to_gcs writes AR weather_data to GCS format" do
    location = create(:weather_location)
    create(:weather_datum, weather_location: location, date: Date.new(2023, 1, 1),
           temperature_max: 10.0, temperature_min: 5.0, temperature_mean: 7.5)
    create(:weather_datum, weather_location: location, date: Date.new(2023, 1, 2),
           temperature_max: 12.0, temperature_min: 6.0, temperature_mean: 9.0)

    gateway = Adapters::WeatherData::Gateways::GcsWeatherDataGateway.new(bucket: @bucket)
    Adapters::WeatherData::Gateways::GcsWeatherDataGateway.stubs(:new).returns(gateway)

    with_env(
      "WEATHER_DATA_STORAGE" => "active_record",
      "GCS_WEATHER_DATA_BUCKET" => "test-bucket"
    ) do
      capture_io { Rake::Task["weather:migrate_to_gcs"].invoke }
    end

    path = "weather_data/#{location.id}/2023.json"
    assert @bucket.stored_files.key?(path), "Expected GCS object #{path}"
    data = JSON.parse(@bucket.stored_files[path])
    assert_equal 2, data.size
    assert data.key?("2023-01-01")
    assert_equal 10.0, data["2023-01-01"]["temperature_max"].to_f
    assert_equal 5.0, data["2023-01-01"]["temperature_min"].to_f
    assert data.key?("2023-01-02")
    assert_equal 12.0, data["2023-01-02"]["temperature_max"].to_f
  end

  test "migrate_to_gcs with DRY_RUN does not write to GCS" do
    location = create(:weather_location)
    create(:weather_datum, weather_location: location, date: Date.new(2023, 1, 1))

    with_env(
      "DRY_RUN" => "1",
      "WEATHER_DATA_STORAGE" => "active_record"
    ) do
      capture_io { Rake::Task["weather:migrate_to_gcs"].invoke }
    end

    assert_empty @bucket.stored_files
  end

  test "migrate_to_gcs with location_id filters to single location" do
    loc1 = create(:weather_location)
    loc2 = create(:weather_location)
    create(:weather_datum, weather_location: loc1, date: Date.new(2023, 1, 1))
    create(:weather_datum, weather_location: loc2, date: Date.new(2023, 1, 1))

    gateway = Adapters::WeatherData::Gateways::GcsWeatherDataGateway.new(bucket: @bucket)
    Adapters::WeatherData::Gateways::GcsWeatherDataGateway.stubs(:new).returns(gateway)

    with_env(
      "WEATHER_DATA_STORAGE" => "active_record",
      "GCS_WEATHER_DATA_BUCKET" => "test-bucket",
      "location_id" => loc1.id.to_s
    ) do
      capture_io { Rake::Task["weather:migrate_to_gcs"].invoke }
    end

    assert @bucket.stored_files.key?("weather_data/#{loc1.id}/2023.json")
    refute @bucket.stored_files.key?("weather_data/#{loc2.id}/2023.json")
  end

  private

  def with_env(env_vars)
    original = env_vars.keys.index_with { |k| ENV[k.to_s] }
    env_vars.each { |k, v| ENV[k.to_s] = v.to_s }
    yield
  ensure
    original.each { |k, v| ENV[k.to_s] = v }
  end
end
