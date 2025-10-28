# frozen_string_literal: true

require 'ostruct'
require 'set'

class PlanSaveService
  include ActiveModel::Model
  
  attr_accessor :user, :session_data, :result
  
  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data
    @result = OpenStruct.new(success: false, error_message: nil)
  end
  
  def call
    Rails.logger.debug I18n.t('services.plan_save_service.debug.session_data_received', data: @session_data.inspect)
    
    ActiveRecord::Base.transaction do
      # 1. マスタデータの作成・取得
      farm = create_or_get_user_farm
      crops = create_user_crops_from_plan
      fields = create_user_fields(farm)
      interaction_rules = create_interaction_rules(crops)
      
      # 2. 計画のコピー
      new_plan = copy_cultivation_plan(farm, crops)
      
      # 3. マスタデータ間の関連付け
      establish_master_data_relationships(farm, crops, fields, interaction_rules)
      
      # 4. 関連データのコピー
      copy_plan_relations(new_plan)
      
      Rails.logger.info I18n.t('services.plan_save_service.messages.service_completed')
      @result.success = true
    end
    
    @result
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.unknown_error', error: e.message)
    Rails.logger.error e.backtrace.join("\n")
    @result.error_message = e.message
    @result
  end
  
  private
  
  def create_or_get_user_farm
    farm_id = @session_data[:farm_id] || @session_data['farm_id']
    Rails.logger.debug I18n.t('services.plan_save_service.debug.farm_id_extracted', farm_id: farm_id)
    
    reference_farm = Farm.find(farm_id)
    Rails.logger.debug I18n.t('services.plan_save_service.debug.reference_farm_found', farm_name: reference_farm.name)
    
    # 新しい農場を作成（バリデーションエラーを捕捉）
    new_farm = @user.farms.build(
      name: "#{reference_farm.name} (コピー #{Time.current.strftime('%Y%m%d_%H%M%S')})",
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude,
      region: reference_farm.region,
      is_reference: false,
      weather_location_id: reference_farm.weather_location_id
    )
    
    unless new_farm.save
      error_message = new_farm.errors.full_messages.join(', ')
      Rails.logger.error "❌ [PlanSaveService] Farm creation failed: #{error_message}"
      # 農場件数制限のエラーの場合は特別なメッセージを返す
      if new_farm.errors[:user].any? { |msg| msg.include?("作成できるFarmは4件までです") }
        raise StandardError, "作成できるFarmは4件までです"
      end
      raise StandardError, error_message
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.messages.farm_created', farm_name: new_farm.name)
    new_farm
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.farm_not_found', farm_id: farm_id)
    raise e
  end
  
  def create_user_crops_from_plan
    # 仕様: セッションにはplan_idのみを持たせる。crop_idsは参照計画から常に導出する。
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    raise StandardError, 'plan_id is required to derive crops' unless plan_id

    reference_plan = CultivationPlan.includes(cultivation_plan_crops: [crop: { crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement] }]).find(plan_id)
    # 登録順にマッピングするために、参照計画のCultivationPlanCropを順序付きで取得
    reference_cultivation_plan_crops = reference_plan.cultivation_plan_crops.order(:id).to_a
    reference_crops = reference_cultivation_plan_crops.map(&:crop).compact
    Rails.logger.debug I18n.t('services.plan_save_service.debug.reference_crops_found', count: reference_crops.count)
    
    user_crops = []
    # 参照CPC(ID) -> ユーザーCrop(ID) のマッピング（登録順ベース）
    @ref_cpc_id_to_user_crop_id = {}
    
    reference_cultivation_plan_crops.each do |reference_cpc|
      reference_crop = reference_cpc.crop
      # 新しい作物を作成（名前重複は許容）
      new_crop = @user.crops.build(
        name: reference_crop.name,
        variety: reference_crop.variety,
        area_per_unit: reference_crop.area_per_unit,
        revenue_per_area: reference_crop.revenue_per_area,
        groups: reference_crop.groups,
        is_reference: false,
        region: reference_crop.region
      )
      
      unless new_crop.save
        error_message = new_crop.errors.full_messages.join(', ')
        Rails.logger.error "❌ [PlanSaveService] Crop creation failed: #{error_message}"
        raise StandardError, error_message
      end
      
      # 作物ステージをコピー
      copy_crop_stages(reference_crop, new_crop)
      
      user_crops << new_crop
      @ref_cpc_id_to_user_crop_id[reference_cpc.id] = new_crop.id
      Rails.logger.info I18n.t('services.plan_save_service.messages.crop_created', crop_name: new_crop.name)
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.debug.user_crops_created', count: user_crops.count)
    user_crops
  end
  
  def create_user_fields(farm)
    field_data = @session_data[:field_data] || @session_data['field_data']
    Rails.logger.debug I18n.t('services.plan_save_service.debug.field_data_extracted', field_data: field_data.inspect)
    
    return [] unless field_data&.any?
    
    user_fields = []
    
    field_data.each do |field_info|
      Rails.logger.debug "🔍 [PlanSaveService] Processing field_info: #{field_info.inspect}"
      
      # ハッシュのキーをシンボルと文字列の両方に対応
      field_name = field_info[:name] || field_info['name']
      field_area = field_info[:area] || field_info['area']
      field_coordinates = field_info[:coordinates] || field_info['coordinates']
      
      Rails.logger.debug "🔍 [PlanSaveService] Extracted: name=#{field_name}, area=#{field_area}, coordinates=#{field_coordinates}"
      
      # 常に新しい圃場を作成（農場ごとにユニークなので重複チェック不要）
      field_attrs = {
        farm: farm,
        user: @user,
        name: field_name,
        area: field_area
      }
      
      # Fieldモデルには座標属性がないため、座標情報はスキップ
      # 必要に応じてdescriptionに座標情報を保存
      if field_coordinates&.is_a?(Array) && field_coordinates.length >= 2
        field_attrs[:description] = "座標: #{field_coordinates[0]}, #{field_coordinates[1]}"
      end
      
      Rails.logger.debug "🔍 [PlanSaveService] Creating field with attrs: #{field_attrs.inspect}"
      
      new_field = farm.fields.create!(field_attrs)
      user_fields << new_field
      Rails.logger.info I18n.t('services.plan_save_service.messages.field_created', field_name: new_field.name)
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.debug.user_fields_created', count: user_fields.count)
    user_fields
  end
  
  def create_interaction_rules(crops)
    # 作物の組み合わせから連作ルールを作成
    interaction_rules = []
    
    # 2つ以上の作物がある場合のみ連作ルールを作成
    return interaction_rules if crops.length < 2
    
    crops.combination(2).each do |crop1, crop2|
      # 作物のgroups属性を取得（なければ作物名を使用）
      group1 = crop1.groups&.first || crop1.name
      group2 = crop2.groups&.first || crop2.name
      
      # 既存の連作ルールがあるかチェック
      existing_rule = @user.interaction_rules.find_by(
        source_group: group1,
        target_group: group2
      ) || @user.interaction_rules.find_by(
        source_group: group2,
        target_group: group1
      )
      
      if existing_rule
        interaction_rules << existing_rule
      else
        # 新しい連作ルールを作成（デフォルトはneutral）
        new_rule = @user.interaction_rules.create!(
          rule_type: 'continuous_cultivation',
          source_group: group1,
          target_group: group2,
          impact_ratio: 1.0, # 影響なし（中立）
          is_directional: false, # 双方向
          description: "#{crop1.name}と#{crop2.name}の連作ルール"
        )
        interaction_rules << new_rule
        
        Rails.logger.info "✅ [PlanSaveService] Created interaction rule: #{group1} ↔ #{group2}"
      end
    end
    
    interaction_rules
  end
  
  def copy_cultivation_plan(farm, crops)
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    Rails.logger.debug I18n.t('services.plan_save_service.debug.plan_id_extracted', plan_id: plan_id)
    
    reference_plan = CultivationPlan.find(plan_id)
    Rails.logger.debug I18n.t('services.plan_save_service.debug.reference_plan_found', plan_name: reference_plan.plan_name)
    
    # 今年の計画期間を計算
    current_year = Date.current.year
    planning_dates = CultivationPlan.calculate_planning_dates(current_year)
    
    # 新しい計画を作成
    new_plan = CultivationPlan.create!(
      farm: farm,
      user: @user,
      total_area: reference_plan.total_area,
      plan_type: 'private',
      plan_year: current_year,
      plan_name: "#{reference_plan.farm.name}の計画",
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date],
      status: 'pending'
    )
    
    Rails.logger.info I18n.t('services.plan_save_service.messages.plan_created', plan_id: new_plan.id)
    new_plan
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_not_found', plan_id: plan_id)
    raise e
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_creation_failed', errors: e.message)
    raise e
  end
  
  def establish_master_data_relationships(farm, crops, fields, interaction_rules)
    # 農場と圃場の関連付けは既にcreate_user_fieldsで完了
    # 作物と連作ルールの関連付けは既にcreate_interaction_rulesで完了
    
    # データ整合性チェック
    Rails.logger.info "🔍 [PlanSaveService] Data integrity check:"
    Rails.logger.info "  - Farm: #{farm.name} (ID: #{farm.id})"
    Rails.logger.info "  - Fields: #{fields.count} fields"
    Rails.logger.info "  - Crops: #{crops.count} crops"
    Rails.logger.info "  - Interaction rules: #{interaction_rules.count} rules"
    
    # 農場の圃場数が一致しているかチェック
    if farm.fields.count != fields.count
      Rails.logger.warn "⚠️ [PlanSaveService] Field count mismatch: farm.fields.count=#{farm.fields.count}, fields.count=#{fields.count}"
    end
    
    # 全てのマスタデータが正しく作成されているかチェック
    unless fields.all?(&:persisted?)
      raise "Some fields were not properly created"
    end
    
    unless crops.all?(&:persisted?)
      raise "Some crops were not properly created"
    end
    
    unless interaction_rules.all?(&:persisted?)
      raise "Some interaction rules were not properly created"
    end
    
    Rails.logger.info "✅ [PlanSaveService] All master data relationships established successfully"
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
    
    # 新規作成したユーザー作物のマップを作成（名前でマッピング）
    user_crops_map = @user.crops.index_by(&:name)
    
    # 1. CultivationPlanFieldを新規作成
    new_fields = reference_plan.cultivation_plan_fields.map do |reference_field|
      CultivationPlanField.create!(
        cultivation_plan: new_plan,
        name: reference_field.name,
        area: reference_field.area,
        daily_fixed_cost: reference_field.daily_fixed_cost,
        description: reference_field.description
      )
    end
    
    # 2. CultivationPlanCropを新規作成（登録順マッピングを使用）
    new_crops = reference_plan.cultivation_plan_crops.order(:id).map do |reference_crop_plan|
      user_crop_id = @ref_cpc_id_to_user_crop_id[reference_crop_plan.id]
      next unless user_crop_id
      
      CultivationPlanCrop.create!(
        cultivation_plan: new_plan,
        crop_id: user_crop_id,
        name: reference_crop_plan.name,
        variety: reference_crop_plan.variety,
        area_per_unit: reference_crop_plan.area_per_unit,
        revenue_per_area: reference_crop_plan.revenue_per_area
      )
    end.compact
    
    # 3. FieldCultivationを新規作成（直接参照）
    field_cultivation_count = 0
    reference_plan.field_cultivations.each do |reference_field_cultivation|
      # 名前でマッチング
      new_field = new_fields.find { |f| f.name == reference_field_cultivation.cultivation_plan_field.name }
      # 作物は登録順マッピングを使用
      mapped_user_crop_id = @ref_cpc_id_to_user_crop_id[reference_field_cultivation.cultivation_plan_crop_id]
      new_crop = new_crops.find { |c| c.crop_id == mapped_user_crop_id }
      next unless new_field && new_crop
      
      FieldCultivation.create!(
        cultivation_plan: new_plan,
        cultivation_plan_field: new_field,
        cultivation_plan_crop: new_crop,
        area: reference_field_cultivation.area,
        start_date: reference_field_cultivation.start_date,
        completion_date: reference_field_cultivation.completion_date,
        cultivation_days: reference_field_cultivation.cultivation_days,
        estimated_cost: reference_field_cultivation.estimated_cost,
        status: reference_field_cultivation.status,
        optimization_result: reference_field_cultivation.optimization_result
      )
      field_cultivation_count += 1
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.debug.plan_relations_copied', 
                            fields: new_fields.count, 
                            crops: new_crops.count, 
                            cultivations: field_cultivation_count)
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_relations_copy_failed', errors: e.message)
    raise e
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
      
      Rails.logger.debug I18n.t('services.plan_save_service.messages.crop_stage_copied', stage_name: stage.name)
      
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
        Rails.logger.debug I18n.t('services.plan_save_service.messages.temperature_requirement_copied', stage_name: stage.name)
      end
      
      # 日照要件をコピー（既に存在する場合はスキップ）
      if reference_stage.sunshine_requirement && !stage.sunshine_requirement
        SunshineRequirement.create!(
          crop_stage_id: stage.id,
          minimum_sunshine_hours: reference_stage.sunshine_requirement.minimum_sunshine_hours,
          target_sunshine_hours: reference_stage.sunshine_requirement.target_sunshine_hours
        )
        Rails.logger.debug I18n.t('services.plan_save_service.messages.sunshine_requirement_copied', stage_name: stage.name)
      end
      
      # 熱量要件をコピー（既に存在する場合はスキップ）
      if reference_stage.thermal_requirement && !stage.thermal_requirement
        ThermalRequirement.create!(
          crop_stage_id: stage.id,
          required_gdd: reference_stage.thermal_requirement.required_gdd
        )
        Rails.logger.debug I18n.t('services.plan_save_service.messages.thermal_requirement_copied', stage_name: stage.name)
      end
    end
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.crop_stage_copy_failed', errors: e.message)
    raise e
  end
end
