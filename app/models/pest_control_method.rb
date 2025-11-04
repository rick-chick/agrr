# frozen_string_literal: true

# PestControlMethod（害虫防除方法）モデル
#
# Attributes:
#   pest_id: 害虫ID（必須）
#   method_type: 防除タイプ（"chemical", "biological", "cultural", "physical"）
#   method_name: 防除方法名
#   description: 説明
#   timing_hint: 実施時期のヒント
class PestControlMethod < ApplicationRecord
  belongs_to :pest

  validates :pest, presence: true
  validates :method_type, presence: true, inclusion: { in: %w[chemical biological cultural physical] }
  validates :method_name, presence: true

  scope :chemical, -> { where(method_type: 'chemical') }
  scope :biological, -> { where(method_type: 'biological') }
  scope :cultural, -> { where(method_type: 'cultural') }
  scope :physical, -> { where(method_type: 'physical') }
end




