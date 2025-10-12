# frozen_string_literal: true

class FreeCropPlan < ApplicationRecord
  # Associations
  belongs_to :farm
  belongs_to :farm_size
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
