# frozen_string_literal: true

class WeatherLocation < ApplicationRecord
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

  # Class methods
  def self.find_or_create_by_coordinates(latitude:, longitude:, elevation: nil, timezone: nil)
    find_or_create_by!(latitude: latitude, longitude: longitude) do |location|
      location.elevation = elevation
      location.timezone = timezone || 'UTC'
    end
  end

  # Instance methods
  def coordinates
    [latitude, longitude]
  end

  def coordinates_string
    "#{latitude},#{longitude}"
  end

  # 指定期間の気象データを取得
  def weather_data_for_period(start_date, end_date)
    weather_data.where(date: start_date..end_date).order(:date)
  end

  # 指定期間に気象データが存在するか
  def has_weather_data_for_period?(start_date, end_date)
    weather_data.where(date: start_date..end_date).count == (end_date - start_date).to_i + 1
  end
end

