# frozen_string_literal: true

class FieldCultivation < ApplicationRecord
  # == Associations ========================================================
  belongs_to :cultivation_plan
  belongs_to :cultivation_plan_field
  belongs_to :cultivation_plan_crop
  has_many :task_schedules, dependent: :destroy

  # == Callbacks ============================================================
  # スナップショット復元などで cultivation_plan_id が未設定のまま保存されると
  # NOT NULL 制約違反になるため、関連する Field/Crop から自動補完する
  before_save :ensure_cultivation_plan_from_associations

  # == Validations =========================================================
  validates :area, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

  # == Enums ===============================================================
  enum :status, {
    pending: "pending",
    optimizing: "optimizing",
    completed: "completed",
    failed: "failed"
  }, default: "pending", prefix: true

  # == Serialization =======================================================
  serialize :optimization_result, coder: JSON

  # == Scopes ==============================================================
  # == Delegates ===========================================================
  delegate :farm, to: :cultivation_plan

  # == Instance Methods ====================================================

  # 作物名を返す
  def crop_display_name
    cultivation_plan_crop.display_name
  end

  # 圃場名を返す
  def field_display_name
    cultivation_plan_field.display_name
  end

  private

  def ensure_cultivation_plan_from_associations
    return if cultivation_plan_id.present?

    if cultivation_plan_field&.cultivation_plan
      self.cultivation_plan = cultivation_plan_field.cultivation_plan
    elsif cultivation_plan_crop&.cultivation_plan
      self.cultivation_plan = cultivation_plan_crop.cultivation_plan
    end
  end
end
