# frozen_string_literal: true

# CropFertilizeApplication（作物肥料施用計画）モデル
#
# Attributes:
#   crop_fertilize_profile_id: 肥料プロファイルID（必須）
#   application_type: 施用タイプ（"basal" または "topdress"、必須）
#   count: 施用回数（必須、デフォルト: 1）
#   schedule_hint: タイミングのガイダンス
#   total_n: このタイプの総窒素量（g/m²、必須）
#   total_p: このタイプの総リン量（g/m²、必須）
#   total_k: このタイプの総カリ量（g/m²、必須）
#   per_application_n: 1回あたりの窒素量（g/m²、追肥の場合のみ）
#   per_application_p: 1回あたりのリン量（g/m²、追肥の場合のみ）
#   per_application_k: 1回あたりのカリ量（g/m²、追肥の場合のみ）
#
# 役割: 肥料施用計画の詳細（基肥/追肥ごと）を保持
class CropFertilizeApplication < ApplicationRecord
  belongs_to :crop_fertilize_profile

  validates :crop_fertilize_profile, presence: true
  validates :application_type, presence: true, inclusion: { in: %w[basal topdress] }
  validates :count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :total_n, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_p, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_k, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # per_applicationのバリデーション（追肥の場合のみ推奨）
  validate :per_application_present_for_topdress, if: -> { application_type == 'topdress' && count > 1 }

  scope :basal, -> { where(application_type: 'basal') }
  scope :topdress, -> { where(application_type: 'topdress') }

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

  private

  # 追肥で複数回の場合、per_applicationが設定されていることを推奨
  def per_application_present_for_topdress
    return if count == 1 # 1回の場合は不要
    
    if per_application_n.blank? && per_application_p.blank? && per_application_k.blank?
      errors.add(:base, '追肥で複数回の場合、1回あたりの施肥量（per_application）を設定することを推奨します')
    end
  end
end

