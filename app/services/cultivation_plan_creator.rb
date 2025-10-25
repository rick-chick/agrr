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
    
    Rails.logger.debug "🔍 [CultivationPlanCreator] crops count: #{@crops.count}"
    @crops.each_with_index { |crop, i| Rails.logger.debug "  - Crop #{i+1}: #{crop.name} (ID: #{crop.id})" }
    @session_id = session_id
    @plan_type = plan_type
    @plan_year = plan_year
    @plan_name = plan_name
    @planning_start_date = planning_start_date
    @planning_end_date = planning_end_date
  end
  
  def call
    ActiveRecord::Base.transaction do
      create_cultivation_plan_and_relations
      Result.new(cultivation_plan: @cultivation_plan, errors: [])
    end
  rescue StandardError => e
    Rails.logger.error "❌ CultivationPlan creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    Result.new(cultivation_plan: nil, errors: [e.message])
  end

  
  def create_cultivation_plan_and_relations
    # CultivationPlanを作成
    create_cultivation_plan
    
    # CultivationPlanCropを作成
    create_cultivation_plan_crops
    
    # CultivationPlanFieldを作成
    create_cultivation_plan_fields
    
    Rails.logger.info "✅ Added #{@cultivation_plan.cultivation_plan_fields.count} fields and #{@cultivation_plan.cultivation_plan_crops.count} crops to CultivationPlan ##{@cultivation_plan.id}"
  end
    
  private
  
  def fields_allocation
    @fields_allocation ||= FieldsAllocator.new(@total_area, @crops).allocate
  end
  
  def calculate_daily_cost(area)
    area * 1.0
  end
  
  def create_cultivation_plan
    # 基本属性
    plan_attrs = {
      farm: @farm,
      user: @user,
      total_area: @total_area,
      plan_type: @plan_type
    }
    
    plan_attrs[:session_id] = @session_id if @session_id.present?
    
    if @plan_type == 'private'
      plan_attrs[:plan_year] = @plan_year
      plan_attrs[:plan_name] = @plan_name
      plan_attrs[:planning_start_date] = @planning_start_date
      plan_attrs[:planning_end_date] = @planning_end_date
    else
      planning_dates = CultivationPlan.calculate_public_planning_dates
      plan_attrs[:planning_start_date] = planning_dates[:start_date]
      plan_attrs[:planning_end_date] = planning_dates[:end_date]
    end
    
    @cultivation_plan = CultivationPlan.create!(plan_attrs)
    
    auth_info = @plan_type == 'public' ? "session_id: #{@cultivation_plan.session_id}" : "user_id: #{@cultivation_plan.user_id}"
    Rails.logger.info "✅ Created CultivationPlan ##{@cultivation_plan.id} (type: #{@plan_type}, #{auth_info})"
    self
  end

  def create_cultivation_plan_crops
    Rails.logger.debug "🔍 [CultivationPlanCreator] Creating CultivationPlanCrops for #{@crops.count} crops"
    @crops.each do |crop|
      Rails.logger.debug "🔍 [CultivationPlanCreator] Creating CultivationPlanCrop for: #{crop.name} (ID: #{crop.id})"
      cultivation_plan_crop = CultivationPlanCrop.create!(
        cultivation_plan: @cultivation_plan,
        crop: crop,
        name: crop.name,
        variety: crop.variety,
        area_per_unit: crop.area_per_unit,
        revenue_per_area: crop.revenue_per_area
      )
      Rails.logger.debug "✅ [CultivationPlanCreator] Created CultivationPlanCrop for: #{crop.name} (ID: #{cultivation_plan_crop.id})"
    end
  end

  def create_cultivation_plan_fields
    Rails.logger.debug "🔍 [CultivationPlanCreator] Creating CultivationPlanFields for #{fields_allocation.count} allocations"
    fields_allocation.each_with_index do |allocation, index|
      field = CultivationPlanField.create!(
        cultivation_plan: @cultivation_plan,
        name: "#{index + 1}",
        area: allocation[:area],
        daily_fixed_cost: calculate_daily_cost(allocation[:area])
      )
      Rails.logger.debug "✅ [CultivationPlanCreator] Created CultivationPlanField ##{field.id} (area: #{allocation[:area]}, name: #{field.name})"
    end
  end
end

