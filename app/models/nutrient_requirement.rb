# frozen_string_literal: true

# NutrientRequirement モデル
# 作物ステージごとの栄養素吸収要件を管理します
#
# フィールド説明:
# - daily_uptake_n: 窒素の日当たり吸収量 (g/m²/day)
# - daily_uptake_p: リン（元素）の日当たり吸収量 (g/m²/day)
# - daily_uptake_k: カリウム（元素）の日当たり吸収量 (g/m²/day)
class NutrientRequirement < ApplicationRecord
  belongs_to :crop_stage

  validates :daily_uptake_n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :daily_uptake_p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :daily_uptake_k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
end
