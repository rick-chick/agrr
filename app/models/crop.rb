# frozen_string_literal: true

# Crop（作物）モデル
#
# Attributes:
#   name: 作物名（必須）
#   variety: 品種名（任意）
#   is_reference: 参照作物フラグ
#   area_per_unit: 単位あたりの栽培面積（㎡）- 正の数値のみ
#   revenue_per_area: 面積あたりの収益（円/㎡）- 0以上の数値のみ
#   user_id: 所有ユーザー（参照作物の場合はnull）
#   groups: 作物グループ（複数の文字列、JSON配列として保存）
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
  has_many :crop_pests, dependent: :destroy
  has_many :pests, through: :crop_pests
  has_many :crop_task_schedule_blueprints, dependent: :destroy
  has_many :crop_task_templates, dependent: :destroy
  has_many :agricultural_tasks, through: :crop_task_templates
  has_many :cultivation_plan_crops, dependent: :restrict_with_exception
  has_many :free_crop_plans, dependent: :restrict_with_exception
  has_many :pesticides, dependent: :restrict_with_exception

  accepts_nested_attributes_for :crop_stages, allow_destroy: true, reject_if: :all_blank

  # groupsをJSON配列としてシリアライズ
  # Temporarily use coder: JSON only (without type: Array) to allow data migration
  serialize :groups, coder: JSON

  # デフォルト値を設定
  after_initialize do
    # Handle both String and Array cases during migration
    if groups.is_a?(String)
      self.groups = [ groups ]
    else
      self.groups ||= []
    end
  end

  validates :name, presence: true
  validates :is_reference, inclusion: { in: [ true, false ] }
  validates :area_per_unit, numericality: { greater_than: 0, allow_nil: true }
  validates :revenue_per_area, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :region, inclusion: { in: %w[jp us in] }, allow_nil: true
  validates :source_crop_id, uniqueness: { scope: :user_id }, allow_nil: true

  # ユーザー作物の件数制限は Domain::Crop::Policies::CropCreateLimitPolicy（Interactor）で実施
  validates :user, presence: true, unless: :is_reference?
  validate :user_must_be_nil_for_reference, if: :is_reference?

  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
  scope :by_region, ->(region) { where(region: region) }
  scope :recent, -> { order(created_at: :desc) }

  private

  def user_must_be_nil_for_reference
    return unless is_reference? && user_id.present?

    errors.add(:user, "は参照データには設定できません")
  end
end
