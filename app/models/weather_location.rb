# frozen_string_literal: true

class WeatherLocation < ApplicationRecord
  serialize :predicted_weather_data, coder: JSON

  # Associations
  has_many :weather_data, dependent: :destroy

  # Validations
  validates :latitude, presence: true,
                       numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :timezone, presence: true
  validates :latitude, uniqueness: { scope: :longitude }

  # Scopes
  scope :by_coordinates, ->(lat, lon) { where(latitude: lat, longitude: lon) }

  # 指定期間の気象データを取得
  def weather_data_for_period(start_date, end_date)
    weather_data_storage_gateway.weather_data_for_period(weather_location_id: id, start_date: start_date, end_date: end_date)
  end

  # 最新の天気データの日付を取得
  def latest_weather_date
    weather_data_storage_gateway.latest_date(weather_location_id: id)
  end

  private

  def weather_data_storage_gateway
    Adapters::WeatherData::WeatherDataGatewayFactory.resolve(clock: CompositionRoot.clock)
  end
end
