# frozen_string_literal: true

# PlanCopier
# 既存の計画を新しい年度にコピーするサービス
class PlanCopier
  Result = Struct.new(:new_plan, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end
  
  def initialize(source_plan:, new_year:, user:, session_id: nil)
    @source_plan = source_plan
    @new_year = new_year
    @user = user
    @session_id = session_id
  end
  
  def call
    ActiveRecord::Base.transaction do
      copy_plan
      Result.new(new_plan: @new_plan, errors: [])
    end
  rescue StandardError => e
    Rails.logger.error "❌ Plan copy failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(new_plan: nil, errors: [e.message])
  end
  
  private
  
  def copy_plan
    # 新しい計画期間を計算
    planning_dates = CultivationPlan.calculate_planning_dates(@new_year)
    
    # 新しい計画を作成
    plan_attrs = {
      farm: @source_plan.farm,
      user: @user,
      total_area: @source_plan.total_area,
      plan_type: 'private',
      plan_year: @new_year,
      plan_name: @source_plan.plan_name,
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date],
      status: 'pending'
    }
    
    # session_idを設定（WebSocket認証に使用）
    plan_attrs[:session_id] = @session_id if @session_id.present?
    
    @new_plan = CultivationPlan.create!(plan_attrs)
    
    Rails.logger.info "✅ Created new plan ##{@new_plan.id} (year: #{@new_year})"
    
    # 圃場をコピー
    @source_plan.cultivation_plan_fields.each do |source_field|
      CultivationPlanField.create!(
        cultivation_plan: @new_plan,
        name: source_field.name,
        area: source_field.area,
        daily_fixed_cost: source_field.daily_fixed_cost,
        description: source_field.description
      )
    end
    
    Rails.logger.info "✅ Copied #{@source_plan.cultivation_plan_fields.count} fields"
    
    # 作物をコピー
    @source_plan.cultivation_plan_crops.each do |source_crop|
      CultivationPlanCrop.create!(
        cultivation_plan: @new_plan,
        crop: source_crop.crop,  # 元のCropへの参照
        name: source_crop.name,
        variety: source_crop.variety,
        area_per_unit: source_crop.area_per_unit,
        revenue_per_area: source_crop.revenue_per_area
      )
    end
    
    Rails.logger.info "✅ Copied #{@source_plan.cultivation_plan_crops.count} crops"
    
    # 栽培記録をコピー（日付は後で最適化で決定されるのでコピーしない）
    field_mapping = {}
    @source_plan.cultivation_plan_fields.each_with_index do |source_field, index|
      field_mapping[source_field.id] = @new_plan.cultivation_plan_fields[index].id
    end
    
    crop_mapping = {}
    @source_plan.cultivation_plan_crops.each_with_index do |source_crop, index|
      crop_mapping[source_crop.id] = @new_plan.cultivation_plan_crops[index].id
    end
    
    @source_plan.field_cultivations.each do |source_fc|
      FieldCultivation.create!(
        cultivation_plan: @new_plan,
        cultivation_plan_field_id: field_mapping[source_fc.cultivation_plan_field_id],
        cultivation_plan_crop_id: crop_mapping[source_fc.cultivation_plan_crop_id],
        area: source_fc.area,
        status: 'pending'
      )
    end
    
    Rails.logger.info "✅ Copied #{@source_plan.field_cultivations.count} field cultivations"
    Rails.logger.info "✅ Plan copy completed: #{@source_plan.id} -> #{@new_plan.id}"
  end
end

