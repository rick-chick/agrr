# frozen_string_literal: true

# CultivationPlanCrop（作付け計画専用作物）モデル
#
# 作付け計画で使用する作物情報のスナップショットを保持します。
# 既存のCropテーブルとは独立しており、その時点の作物情報を保存します。
#
# Attributes:
#   name: 作物名（必須）
#   variety: 品種名（任意）
#   area_per_unit: 単位あたりの栽培面積（㎡）
#   revenue_per_area: 面積あたりの収益（円/㎡）
#   crop_id: 元のCropテーブルへの参照（必須）
#
class CultivationPlanCrop < ApplicationRecord
  # == Associations ========================================================
  belongs_to :cultivation_plan
  belongs_to :crop
  has_many :field_cultivations, dependent: :destroy
  
  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :crop_id, presence: true
  validates :area_per_unit, numericality: { greater_than: 0 }, allow_nil: true
  validates :revenue_per_area, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # == Instance Methods ====================================================
  
  def display_name
    if variety.present?
      "#{name}（#{variety}）"
    else
      name
    end
  end
end

