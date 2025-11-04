# frozen_string_literal: true

# PestThermalRequirement（害虫熱量要件）モデル
#
# Attributes:
#   pest_id: 害虫ID（必須）
#   required_gdd: 必要な総積算温度（GDD）
#   first_generation_gdd: 第一世代のGDD
class PestThermalRequirement < ApplicationRecord
  belongs_to :pest

  validates :pest, presence: true
end




