# frozen_string_literal: true

# Pesticide（農薬）モデル
#
# Attributes:
#   id: 農薬ID（主キー）
#   name: 農薬名（必須）
#   active_ingredient: 有効成分名
#   description: 説明文
#   is_reference: 参照データフラグ
#   user_id: 所有ユーザー（参照農薬の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用農薬マスタ
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の農薬
#     - user_idが設定される（ユーザー所有）
class Pesticide < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :crop
  belongs_to :pest

  has_one :pesticide_usage_constraint, dependent: :destroy
  has_one :pesticide_application_detail, dependent: :destroy

  accepts_nested_attributes_for :pesticide_usage_constraint, allow_destroy: true
  accepts_nested_attributes_for :pesticide_application_detail, allow_destroy: true

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [ true, false ] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :crop, presence: true
  validates :pest, presence: true
  validates :source_pesticide_id, uniqueness: { scope: :user_id }, allow_nil: true
  validates :region, inclusion: { in: %w[jp us in] }, allow_nil: true

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }

  # 参照農薬は user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end
