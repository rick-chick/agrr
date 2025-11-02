# frozen_string_literal: true

# CropFertilizeApplication（作物肥料施用計画）モデル
#
# Attributes:
#   crop_fertilize_profile_id: 肥料プロファイルID（必須）
#   application_type: 施用タイプ（"basal" または "topdress"、必須）
#   count: 施用回数（必須、デフォルト: 1）
#   schedule_hint: タイミングのガイダンス
#   per_application_n: 1回あたりの窒素量（g/m²、追肥の場合のみ）
#   per_application_p: 1回あたりのリン量（g/m²、追肥の場合のみ）
#   per_application_k: 1回あたりのカリ量（g/m²、追肥の場合のみ）
#
# 役割: 肥料施用計画の詳細（基肥/追肥ごと）を保持
# Note: total_n, total_p, total_kは削除され、計算メソッドで取得可能
class CropFertilizeApplication < ApplicationRecord
  belongs_to :crop_fertilize_profile

  validates :crop_fertilize_profile, presence: true
  validates :application_type, presence: true, inclusion: { in: %w[basal topdress] }
  validates :count, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :basal, -> { where(application_type: 'basal') }
  scope :topdress, -> { where(application_type: 'topdress') }

  # 計算メソッド: per_applicationから総量を計算
  def total_n
    return 0 if per_application_n.blank?
    per_application_n * count
  end

  def total_p
    return 0 if per_application_p.blank?
    per_application_p * count
  end

  def total_k
    return 0 if per_application_k.blank?
    per_application_k * count
  end

  # 施用タイプの日本語名
  def application_type_name
    case application_type
    when 'basal'
      '基肥'
    when 'topdress'
      '追肥'
    else
      application_type
    end
  end
end

