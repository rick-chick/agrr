# frozen_string_literal: true

require 'ostruct'

class PlanSaveService
  include ActiveModel::Model
  
  attr_accessor :user, :session_data, :result
  
  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data
    @result = OpenStruct.new(success: false, error_message: nil)
  end
  
  def call
    ActiveRecord::Base.transaction do
      # 1. マスタデータの作成・取得
      farm = create_or_get_user_farm
      crops = create_or_get_user_crops
      interaction_rules = create_interaction_rules(crops)
      
      # 2. 計画のコピー
      new_plan = copy_cultivation_plan(farm, crops)
      
      # 3. マスタデータ間の関連付け
      establish_master_data_relationships(farm, crops, interaction_rules)
      
      # 4. 関連データのコピー
      copy_plan_relations(new_plan)
      
      @result.success = true
    end
    
    @result
  rescue => e
    Rails.logger.error "PlanSaveService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @result.error_message = e.message
    @result
  end
  
  private
  
  def create_or_get_user_farm
    farm_id = @session_data[:farm_id] || @session_data['farm_id']
    reference_farm = Farm.find(farm_id)
    
    # 既存の農場があるかチェック
    existing_farm = @user.farms.find_by(
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude
    )
    
    return existing_farm if existing_farm
    
    # 新しい農場を作成（weather_location_idを渡す）
    @user.farms.create!(
      name: "#{reference_farm.name} (コピー)",
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude,
      region: reference_farm.region,
      is_reference: false,
      weather_location_id: reference_farm.weather_location_id
    )
  end
  
  def create_or_get_user_crops
    crop_ids = @session_data[:crop_ids] || @session_data['crop_ids']
    reference_crops = Crop.includes(crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement]).where(id: crop_ids)
    user_crops = []
    
    reference_crops.each do |reference_crop|
      # 既存の作物があるかチェック
      existing_crop = @user.crops.includes(crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement]).find_by(name: reference_crop.name)
      
      if existing_crop
        # 既存の作物にステージ要件があるかチェック
        missing_requirements = existing_crop.crop_stages.any? do |stage|
          !stage.temperature_requirement || !stage.thermal_requirement
        end
        
        if missing_requirements
          # ステージ要件が欠けている場合はコピー
          Rails.logger.info "⚠️  [PlanSaveService] Copying missing requirements for existing crop: #{existing_crop.name}"
          copy_crop_stages(reference_crop, existing_crop)
        end
        
        user_crops << existing_crop
      else
        # 新しい作物を作成
        new_crop = @user.crops.create!(
          name: reference_crop.name,
          variety: reference_crop.variety,
          area_per_unit: reference_crop.area_per_unit,
          revenue_per_area: reference_crop.revenue_per_area,
          groups: reference_crop.groups,
          is_reference: false,
          region: reference_crop.region
        )
        
        # 作物ステージをコピー
        copy_crop_stages(reference_crop, new_crop)
        
        user_crops << new_crop
      end
    end
    
    user_crops
  end
  
  def create_interaction_rules(crops)
    # InteractionRuleはグループベースなので、個別コピーは不要
    # 既存のルールを参照する
    []
  end
  
  def copy_cultivation_plan(farm, crops)
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    reference_plan = CultivationPlan.find(plan_id)
    
    @user.cultivation_plans.create!(
      farm: farm,
      plan_type: :private,
      total_area: reference_plan.total_area,
      status: :completed,
      planning_start_date: reference_plan.planning_start_date,
      planning_end_date: reference_plan.planning_end_date,
      plan_year: reference_plan.plan_year || Date.current.year,
      total_profit: reference_plan.total_profit,
      total_revenue: reference_plan.total_revenue,
      total_cost: reference_plan.total_cost,
      optimization_time: reference_plan.optimization_time,
      algorithm_used: reference_plan.algorithm_used,
      is_optimal: reference_plan.is_optimal,
      optimization_summary: reference_plan.optimization_summary,
      predicted_weather_data: reference_plan.predicted_weather_data
    )
  end
  
  def establish_master_data_relationships(farm, crops, interaction_rules)
    # 農場と圃場の関連付けは不要（CultivationPlanFieldは計画専用）
    # 作物と連作ルールの関連付けは既にcreate_interaction_rulesで完了
    # ここでは追加の関連付け処理があれば実装
  end
  
  def copy_plan_relations(new_plan)
    # 参照計画を取得（includesで関連データを一括読み込み）
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    reference_plan = CultivationPlan.includes(
      :cultivation_plan_fields,
      :cultivation_plan_crops,
      :field_cultivations,
      cultivation_plan_crops: :crop,
      field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop]
    ).find(plan_id)
    
    # CultivationPlanFieldをコピー（バルクインサート）
    field_data = reference_plan.cultivation_plan_fields.map do |reference_field|
      {
        cultivation_plan_id: new_plan.id,
        name: reference_field.name,
        area: reference_field.area,
        daily_fixed_cost: reference_field.daily_fixed_cost,
        description: reference_field.description,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    CultivationPlanField.insert_all(field_data) if field_data.any?
    
    # CultivationPlanCropをコピー（バルクインサート）
    crop_plan_data = []
    reference_plan.cultivation_plan_crops.each do |reference_crop_plan|
      crop = @user.crops.find_by(name: reference_crop_plan.crop.name)
      next unless crop
      
      crop_plan_data << {
        cultivation_plan_id: new_plan.id,
        crop_id: crop.id,
        name: reference_crop_plan.name,
        variety: reference_crop_plan.variety,
        area_per_unit: reference_crop_plan.area_per_unit,
        revenue_per_area: reference_crop_plan.revenue_per_area,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    CultivationPlanCrop.insert_all(crop_plan_data) if crop_plan_data.any?
    
    # 作成したCultivationPlanFieldとCultivationPlanCropを再読み込み（名前でマップを作成）
    new_plan.cultivation_plan_fields.reload
    new_plan.cultivation_plan_crops.reload
    
    field_map = new_plan.cultivation_plan_fields.index_by(&:name)
    crop_map = new_plan.cultivation_plan_crops.index_by(&:name)
    
    # FieldCultivationをコピー（バルクインサート）
    field_cultivation_data = []
    reference_plan.field_cultivations.each do |reference_field_cultivation|
      plan_field = field_map[reference_field_cultivation.cultivation_plan_field.name]
      next unless plan_field
      
      plan_crop = crop_map[reference_field_cultivation.cultivation_plan_crop.name]
      next unless plan_crop
      
      field_cultivation_data << {
        cultivation_plan_id: new_plan.id,
        cultivation_plan_field_id: plan_field.id,
        cultivation_plan_crop_id: plan_crop.id,
        area: reference_field_cultivation.area,
        start_date: reference_field_cultivation.start_date,
        completion_date: reference_field_cultivation.completion_date,
        estimated_cost: reference_field_cultivation.estimated_cost,
        status: reference_field_cultivation.status,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    FieldCultivation.insert_all(field_cultivation_data) if field_cultivation_data.any?
  end
  
  def copy_crop_stages(reference_crop, new_crop)
    reference_crop.crop_stages.each do |reference_stage|
      # 既存のステージを検索
      existing_stage = new_crop.crop_stages.find_by(name: reference_stage.name)
      stage = existing_stage || CropStage.create!(
        crop_id: new_crop.id,
        name: reference_stage.name,
        order: reference_stage.order
      )
      
      # 温度要件をコピー（既に存在する場合はスキップ）
      if reference_stage.temperature_requirement && !stage.temperature_requirement
        TemperatureRequirement.create!(
          crop_stage_id: stage.id,
          base_temperature: reference_stage.temperature_requirement.base_temperature,
          optimal_min: reference_stage.temperature_requirement.optimal_min,
          optimal_max: reference_stage.temperature_requirement.optimal_max,
          low_stress_threshold: reference_stage.temperature_requirement.low_stress_threshold,
          high_stress_threshold: reference_stage.temperature_requirement.high_stress_threshold,
          frost_threshold: reference_stage.temperature_requirement.frost_threshold,
          sterility_risk_threshold: reference_stage.temperature_requirement.sterility_risk_threshold,
          max_temperature: reference_stage.temperature_requirement.max_temperature
        )
      end
      
      # 日照要件をコピー（既に存在する場合はスキップ）
      if reference_stage.sunshine_requirement && !stage.sunshine_requirement
        SunshineRequirement.create!(
          crop_stage_id: stage.id,
          minimum_sunshine_hours: reference_stage.sunshine_requirement.minimum_sunshine_hours,
          target_sunshine_hours: reference_stage.sunshine_requirement.target_sunshine_hours
        )
      end
      
      # 熱量要件をコピー（既に存在する場合はスキップ）
      if reference_stage.thermal_requirement && !stage.thermal_requirement
        ThermalRequirement.create!(
          crop_stage_id: stage.id,
          required_gdd: reference_stage.thermal_requirement.required_gdd
        )
      end
    end
  end
end
