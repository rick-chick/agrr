# frozen_string_literal: true

class WeatherDatum < ApplicationRecord
  # Associations
  belongs_to :weather_location

  # Validations
  validates :date, presence: true
  validates :date, uniqueness: { scope: :weather_location_id }
end
