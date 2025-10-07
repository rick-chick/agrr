# frozen_string_literal: true

class WeatherDatum < ApplicationRecord
  # Associations
  belongs_to :weather_location

  # Validations
  validates :date, presence: true
  validates :date, uniqueness: { scope: :weather_location_id }

  # Scopes
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_year, ->(year) { where('strftime("%Y", date) = ?', year.to_s) }
  scope :recent, -> { order(date: :desc) }

  # Instance methods
  def temperature_range
    return nil unless temperature_max && temperature_min
    temperature_max - temperature_min
  end

  def has_precipitation?
    precipitation.present? && precipitation > 0
  end
end

