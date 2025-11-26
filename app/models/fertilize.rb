# frozen_string_literal: true

# Fertilize（肥料）モデル
#
# Attributes:
#   name: 肥料名（必須、一意）
#   n: 窒素含有率（%）
#   p: リン含有率（%）
#   k: カリ含有率（%）
#   description: 説明文
#   package_size: 容量（kg、数値型）
#   is_reference: 参照肥料フラグ（デフォルト: true）
#   user_id: 所有ユーザー（参照肥料の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用肥料
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の肥料
#     - user_idが設定される（ユーザー所有）
class Fertilize < ApplicationRecord
  belongs_to :user, optional: true
  
  # バリデーション
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :is_reference, inclusion: { in: [true, false] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :package_size, numericality: { greater_than: 0, allow_nil: true }
  validates :source_fertilize_id, uniqueness: { scope: :user_id }, allow_nil: true
  
  # スコープ
  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }
  
  # ヘルパーメソッド
  def has_nutrient?(nutrient)
    case nutrient.to_sym
    when :n
      n.present? && n > 0
    when :p
      p.present? && p > 0
    when :k
      k.present? && k > 0
    else
      false
    end
  end
  
  def npk_summary
    [n, p, k].compact.map { |v| v.to_i }.join('-')
  end

  # 参照肥料は user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end

