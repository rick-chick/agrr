# frozen_string_literal: true

# InteractionRule（作物相互作用ルール）モデル
#
# Attributes:
#   rule_type: ルールタイプ（必須）
#     - continuous_cultivation: 連作
#     将来的な拡張:
#     - companion_planting: 混植（コンパニオンプランツ）
#   source_group: 影響を与える元のグループ名（必須）
#   target_group: 影響を受ける対象のグループ名（必須）
#   impact_ratio: 影響係数（必須、0以上の数値）
#     - 1.0 = 影響なし（中立）
#     - 0.7 = 30%減少（ネガティブな影響）
#     - 1.2 = 20%増加（ポジティブな影響）
#     - 0.0 = 栽培不可
#   is_directional: 方向性の有無（デフォルト: true）
#     - true: 方向性あり（source → target のみ）
#     - false: 双方向（相互に影響）
#   description: ルールの説明文（任意）
#   user_id: 所有ユーザー（参照ルールの場合はnull）
#   is_reference: 参照ルールフラグ
#
# is_reference フラグについて:
#   - true: システムが提供する参照用ルール（標準の連作・輪作効果など）
#     - 管理者のみが管理画面で表示・編集可能
#     - 一般ユーザーからは見えない（作付け計画時に自動適用）
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人のカスタムルール
#     - 作成したユーザーのみが管理可能
#
class InteractionRule < ApplicationRecord
  belongs_to :user, optional: true

  validates :rule_type, presence: true
  validates :source_group, presence: true
  validates :target_group, presence: true
  validates :impact_ratio, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :is_reference, inclusion: { in: [ true, false ] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?
  validates :source_interaction_rule_id, uniqueness: { scope: :user_id }, allow_nil: true
  validates :region, inclusion: { in: %w[jp us in] }, allow_nil: true

  # Scopes
  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }

  # デフォルト値を設定
  after_initialize do
    self.is_directional = true if is_directional.nil?
  end

  # 参照ルールは user を持たない（システム所有）
  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end
