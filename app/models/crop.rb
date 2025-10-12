# frozen_string_literal: true

# Crop（作物）モデル
#
# Attributes:
#   name: 作物名（必須）
#   variety: 品種名（任意）
#   is_reference: 参照作物フラグ
#   area_per_unit: 単位あたりの栽培面積（㎡）- 正の数値のみ
#   revenue_per_area: 面積あたりの収益（円/㎡）- 0以上の数値のみ
#   agrr_crop_id: agrrコマンドから取得した作物ID（更新時の識別に使用）
#   user_id: 所有ユーザー（参照作物の場合はnull）
#
# is_reference フラグについて:
#   - true: システムが提供する参照用作物
#     - 管理画面で編集・削除可能
#     - 一般ユーザーも作物管理画面で参照（閲覧）可能
#     - user_idはnull（システム所有）
#   - false: ユーザーが作成した個人の作物
#     - 作成したユーザーのみが管理可能
class Crop < ApplicationRecord
  belongs_to :user, optional: true
  has_many :crop_stages, dependent: :destroy

  accepts_nested_attributes_for :crop_stages, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :area_per_unit, numericality: { greater_than: 0, allow_nil: true }
  validates :revenue_per_area, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :recent, -> { order(created_at: :desc) }
end


