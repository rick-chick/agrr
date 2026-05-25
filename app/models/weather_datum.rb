# frozen_string_literal: true

class WeatherDatum < ApplicationRecord
  # Associations
  belongs_to :weather_location

  # Validations
  validates :date, presence: true
  validates :date, uniqueness: { scope: :weather_location_id }

  def to_dto
    Domain::WeatherData::Dtos::WeatherData.new(
      date: date,
      temperature_max: temperature_max,
      temperature_min: temperature_min,
      temperature_mean: temperature_mean,
      precipitation: precipitation || 0.0,
      sunshine_hours: sunshine_hours || 0.0,
      wind_speed: wind_speed || 0.0,
      weather_code: weather_code || 0
    )
  end
end
