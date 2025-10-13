# frozen_string_literal: true

class FieldCultivation < ApplicationRecord
  # == Associations ========================================================
  belongs_to :cultivation_plan
  belongs_to :cultivation_plan_field
  belongs_to :cultivation_plan_crop
  
  # 既存のFieldやCropテーブルへの参照も残す（後方互換性のため）
  belongs_to :field, optional: true
  belongs_to :crop, optional: true
  
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
  
  # == Instance Methods ====================================================
  
  # 作物名を返す
  def crop_display_name
    cultivation_plan_crop&.display_name || crop&.name || '不明'
  end
  
  # 圃場名を返す
  def field_display_name
    cultivation_plan_field&.display_name || field&.name || '不明'
  end
  
  # 作物情報を取得
  def crop_info
    if cultivation_plan_crop
      {
        name: cultivation_plan_crop.name,
        variety: cultivation_plan_crop.variety,
        area_per_unit: cultivation_plan_crop.area_per_unit,
        revenue_per_area: cultivation_plan_crop.revenue_per_area,
        agrr_id: cultivation_plan_crop.agrr_crop_id
      }
    elsif crop
      {
        name: crop.name,
        variety: crop.variety,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area,
        agrr_id: crop.agrr_crop_id
      }
    else
      {}
    end
  end
  
  # 圃場情報を取得
  def field_info
    if cultivation_plan_field
      {
        name: cultivation_plan_field.name,
        area: cultivation_plan_field.area,
        daily_fixed_cost: cultivation_plan_field.daily_fixed_cost
      }
    elsif field
      {
        name: field.name,
        area: field.area,
        daily_fixed_cost: field.daily_fixed_cost
      }
    else
      {}
    end
  end
  
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

