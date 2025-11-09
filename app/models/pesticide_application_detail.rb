# frozen_string_literal: true

# PesticideApplicationDetail（農薬施用詳細）モデル
#
# Attributes:
#   pesticide_id: 農薬ID（必須）
#   dilution_ratio: 希釈倍率（例: "1000倍"）
#   amount_per_m2: 1m²あたりの量
#   amount_unit: 単位（例: "ml", "g"）
#   application_method: 施用方法（例: "散布"）
class PesticideApplicationDetail < ApplicationRecord
  belongs_to :pesticide

  validates :pesticide, presence: true
  validates :amount_per_m2, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validate :amount_and_unit_consistency

  private

  def amount_and_unit_consistency
    if amount_unit.present? && amount_per_m2.nil?
      errors.add(:amount_unit, "requires amount_per_m2")
    end

    if amount_per_m2.present? && amount_unit.nil?
      errors.add(:amount_per_m2, "requires amount_unit")
    end
  end
end








