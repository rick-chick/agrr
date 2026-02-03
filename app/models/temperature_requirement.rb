# frozen_string_literal: true

# TemperatureRequirement モデル
# 作物ステージごとの温度要件を管理します
#
# フィールド説明:
# - base_temperature: 最低限界温度（作物が生育可能な最低温度）
# - optimal_min: 最適温度範囲の下限
# - optimal_max: 最適温度範囲の上限
# - low_stress_threshold: 低温ストレス閾値
# - high_stress_threshold: 高温ストレス閾値
# - frost_threshold: 霜害閾値
# - sterility_risk_threshold: 不稔リスク閾値
class TemperatureRequirement < ApplicationRecord
  belongs_to :crop_stage

  # 数値フィールドは数値であることを検証する
  validates :base_temperature, :optimal_min, :optimal_max,
            :low_stress_threshold, :high_stress_threshold,
            :frost_threshold, :sterility_risk_threshold, :max_temperature,
            numericality: true, allow_nil: true
end


