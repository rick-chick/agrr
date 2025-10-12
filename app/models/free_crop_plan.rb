# frozen_string_literal: true

# @deprecated このモデルは非推奨です。代わりに CultivationPlan と FieldCultivation を使用してください。
# 既存データの互換性のためにのみ保持されています。
class FreeCropPlan < ApplicationRecord
  # Associations
  belongs_to :farm
  belongs_to :crop

  # Enums
  enum :status, {
    pending: 'pending',       # 初期状態
    calculating: 'calculating', # 計算中
    completed: 'completed',   # 完了
    failed: 'failed'          # 失敗
  }, default: 'pending'

  # Validations
  validates :status, presence: true
  validates :session_id, length: { maximum: 255 }
  validates :area_sqm, presence: true, numericality: { greater_than: 0, only_integer: true }

  # Scopes
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }

  # Serialization
  serialize :plan_data, coder: JSON

  # Methods
  def start_calculation!
    update!(status: 'calculating')
  end

  def complete_calculation!(data)
    update!(
      status: 'completed',
      plan_data: data
    )
  end

  def mark_failed!(error_message)
    update!(
      status: 'failed',
      plan_data: { error: error_message }
    )
  end
end
