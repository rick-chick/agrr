# frozen_string_literal: true

# CultivationPlanField（作付け計画専用圃場）モデル
#
# 作付け計画で使用する仮想的な圃場情報を保持します。
# 既存のFieldテーブルとは独立しており、作付け計画のシミュレーション専用です。
#
# Attributes:
#   name: 圃場名（必須）
#   area: 面積（㎡、必須）
#   daily_fixed_cost: 日次固定コスト（円/日）
#   description: 説明（任意）
#
class CultivationPlanField < ApplicationRecord
  # == Associations ========================================================
  belongs_to :cultivation_plan
  has_many :field_cultivations, dependent: :destroy
  
  # == Validations =========================================================
  validates :name, presence: true, length: { maximum: 100 }
  validates :area, presence: true, numericality: { greater_than: 0 }
  validates :daily_fixed_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # == Instance Methods ====================================================
  
  def display_name
    name.presence || I18n.t('models.cultivation_plan_field.default_name', id: id)
  end
end

