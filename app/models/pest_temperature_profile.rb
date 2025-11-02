# frozen_string_literal: true

# PestTemperatureProfile（害虫温度プロファイル）モデル
#
# Attributes:
#   pest_id: 害虫ID（必須）
#   base_temperature: 最低限界温度
#   max_temperature: 最高限界温度
class PestTemperatureProfile < ApplicationRecord
  belongs_to :pest

  validates :pest, presence: true
end

