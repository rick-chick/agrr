# frozen_string_literal: true

# Pest（害虫）モデル
#
# Attributes:
#   id: 害虫ID（主キー）
#   name: 害虫名（必須）
#   name_scientific: 学名
#   family: 科
#   order: 目
#   description: 説明
#   occurrence_season: 発生時期
#   is_reference: 参照データフラグ
#   user_id: 所有ユーザー（参照害虫の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用害虫マスタ
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の害虫
#     - user_idが設定される（ユーザー所有）
class Pest < ApplicationRecord
  belongs_to :user, optional: true
  has_one :pest_temperature_profile, dependent: :destroy
  has_one :pest_thermal_requirement, dependent: :destroy
  has_many :pest_control_methods, dependent: :destroy
  has_many :crop_pests, dependent: :destroy
  has_many :crops, through: :crop_pests
  has_many :pesticides, dependent: :restrict_with_exception

  accepts_nested_attributes_for :pest_temperature_profile, allow_destroy: true
  accepts_nested_attributes_for :pest_thermal_requirement, allow_destroy: true
  accepts_nested_attributes_for :pest_control_methods, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [ true, false ] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :source_pest_id, uniqueness: { scope: :user_id }, allow_nil: true
  validates :region, inclusion: { in: %w[jp us in] }, allow_nil: true

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }

  # 参照害虫は user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end
