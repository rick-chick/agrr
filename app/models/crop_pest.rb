# frozen_string_literal: true

# CropPest（作物と害虫の関連）モデル
#
# Attributes:
#   crop_id: 作物ID（必須）
#   pest_id: 害虫ID（必須）
#
# 役割: 作物と害虫の多対多の関係を管理
class CropPest < ApplicationRecord
  belongs_to :crop
  belongs_to :pest

  validates :crop, presence: true
  validates :pest, presence: true
  validates :pest_id, uniqueness: { scope: :crop_id }
end

