# frozen_string_literal: true

# Fertilize（肥料）モデル
#
# Attributes:
#   name: 肥料名（必須、一意）
#   n: 窒素含有率（%）
#   p: リン含有率（%）
#   k: カリ含有率（%）
#   description: 説明文
#   package_size: 容量（例: "20kg"）
#   is_reference: 参照肥料フラグ（デフォルト: true）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用肥料
#   - false: ユーザーが作成した個人の肥料
class Fertilize < ApplicationRecord
  # バリデーション
  validates :name, presence: true, uniqueness: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  # スコープ
  scope :reference, -> { where(is_reference: true) }
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
end

