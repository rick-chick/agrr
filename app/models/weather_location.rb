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

  # Class methods
  def self.find_or_create_by_coordinates(latitude:, longitude:, elevation: nil, timezone: nil)
    # 既存のレコードを検索
    location = find_by(latitude: latitude, longitude: longitude)
    return location if location
    
    # 存在しない場合は作成（競合状態を考慮）
    create!(
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
      timezone: timezone || 'UTC'
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # 別のジョブが同時に作成した場合は再取得
    find_by!(latitude: latitude, longitude: longitude)
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

  # 最新の天気データの日付を取得
  def latest_weather_date
    weather_data.maximum(:date)
  end

  # 最古の天気データの日付を取得
  def earliest_weather_date
    weather_data.minimum(:date)
  end
end

