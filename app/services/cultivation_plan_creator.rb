# frozen_string_literal: true

class CultivationPlanCreator
  Result = Struct.new(:cultivation_plan, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end
  
  def initialize(farm:, total_area:, crops:, user: nil, session_id: nil, plan_type: 'public', plan_year: nil, plan_name: nil, planning_start_date: nil, planning_end_date: nil)
    @farm = farm
    @total_area = total_area
    @crops = crops
    @user = user
    @session_id = session_id
    @plan_type = plan_type
    @plan_year = plan_year
    @plan_name = plan_name
    @planning_start_date = planning_start_date
    @planning_end_date = planning_end_date
  end
  
  def call
    ActiveRecord::Base.transaction do
      create_plan_with_cultivations
      Result.new(cultivation_plan: @cultivation_plan, errors: [])
    end
  rescue StandardError => e
    Rails.logger.error "❌ CultivationPlan creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(cultivation_plan: nil, errors: [e.message])
  end
  
  private
  
  def create_plan_with_cultivations
    # 基本属性
    plan_attrs = {
      farm: @farm,
      user: @user,
      total_area: @total_area,
      plan_type: @plan_type
    }
    
    # public計画の場合はsession_idを追加
    plan_attrs[:session_id] = @session_id if @plan_type == 'public'
    
    # private計画の場合は計画情報を追加
    if @plan_type == 'private'
      plan_attrs[:plan_year] = @plan_year
      plan_attrs[:plan_name] = @plan_name
      plan_attrs[:planning_start_date] = @planning_start_date
      plan_attrs[:planning_end_date] = @planning_end_date
    end
    
    @cultivation_plan = CultivationPlan.create!(plan_attrs)
    
    fields_allocation.each_with_index do |allocation, index|
      create_field_cultivation(allocation, index)
    end
    
    Rails.logger.info "✅ Created CultivationPlan ##{@cultivation_plan.id} with #{@cultivation_plan.field_cultivations.count} field cultivations"
  end
  
  def create_field_cultivation(allocation, index)
    crop = allocation[:crop]
    
    # 作付け計画専用の圃場を作成
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場#{index + 1}",
      area: allocation[:area],
      daily_fixed_cost: calculate_daily_cost(allocation[:area])
    )
    
    # 作付け計画専用の作物を作成（スナップショット）
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: crop.name,
      variety: crop.variety,
      area_per_unit: crop.area_per_unit,
      revenue_per_area: crop.revenue_per_area,
      agrr_crop_id: crop.id  # CropのIDを保存（後で元の作物を取得するため）
    )
    
    # FieldCultivationを作成
    FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: allocation[:area]
    )
  end
  
  def fields_allocation
    @fields_allocation ||= FieldsAllocator.new(@total_area, @crops).allocate
  end
  
  def calculate_daily_cost(area)
    area * 1.0  # 1円/㎡/日
  end
end

