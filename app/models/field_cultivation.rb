# frozen_string_literal: true

class FieldCultivation < ApplicationRecord
  # == Associations ========================================================
  belongs_to :cultivation_plan
  belongs_to :field
  belongs_to :crop
  
  # == Validations =========================================================
  validates :area, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  
  # == Enums ===============================================================
  enum :status, {
    pending: 'pending',
    optimizing: 'optimizing',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending', prefix: true
  
  # == Serialization =======================================================
  serialize :optimization_result, coder: JSON
  
  # == Scopes ==============================================================
  scope :this_year, -> do
    where("start_date >= ? AND start_date <= ?", 
          Date.current, 
          Date.current.end_of_year)
  end
  
  scope :next_year, -> do
    where("start_date >= ?", Date.current.next_year.beginning_of_year)
  end
  
  # == Delegates ===========================================================
  delegate :farm, to: :cultivation_plan
  delegate :name, to: :crop, prefix: true
  delegate :name, to: :field, prefix: true
  
  # == Instance Methods ====================================================
  
  def start_optimizing!
    update!(status: :optimizing)
  end
  
  def complete_with_result!(result)
    update!(
      status: :completed,
      start_date: result[:start_date],
      completion_date: result[:completion_date],
      cultivation_days: result[:days],
      estimated_cost: result[:cost],
      optimization_result: result
    )
  end
  
  def fail_with_error!(error_message)
    update!(
      status: :failed,
      optimization_result: { error: error_message }
    )
  end
  
  def year_label
    return unless start_date
    start_date.year == Date.current.year ? '今年' : '来年'
  end
end

