# frozen_string_literal: true

# PesticideUsageConstraint（農薬使用制約）モデル
#
# Attributes:
#   pesticide_id: 農薬ID（必須）
#   min_temperature: 最小適用温度 (°C)
#   max_temperature: 最大適用温度 (°C)
#   max_wind_speed_m_s: 最大風速 (m/s)
#   max_application_count: 1シーズンあたりの最大施用回数
#   harvest_interval_days: 収穫前日数 (PHI)
#   other_constraints: その他の制約（テキスト）
class PesticideUsageConstraint < ApplicationRecord
  belongs_to :pesticide

  validates :pesticide, presence: true
  validates :max_wind_speed_m_s, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :max_application_count, numericality: { greater_than: 0, allow_nil: true }
  validates :harvest_interval_days, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  validate :min_temperature_must_be_less_than_max

  private

  def min_temperature_must_be_less_than_max
    return unless min_temperature && max_temperature

    if min_temperature > max_temperature
      errors.add(:min_temperature, "must be less than or equal to max_temperature")
    end
  end
end




