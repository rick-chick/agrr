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

  # 最新の天気データの日付を取得
  def latest_weather_date
    weather_data.maximum(:date)
  end
end
