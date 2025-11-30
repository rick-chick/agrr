# frozen_string_literal: true

require 'set'

class PlanSaveService
  include ActiveModel::Model

  class InvalidTaskScheduleItemError < StandardError; end

  class Result
    attr_accessor :success, :error_message, :new_plan
    attr_reader :skipped_items

    def initialize
      @success = false
      @error_message = nil
      @new_plan = nil
      @skipped_items = { farm: [], fields: [], crops: [], fertilizes: [], pests: [], agricultural_tasks: [], pesticides: [], interaction_rules: [] }
    end

    def success?
      success
    end

    def skipped?
      @skipped_items.values.any?(&:present?)
    end

    def add_skip(category, value)
      (@skipped_items[category] ||= []) << value
    end
  end

  attr_accessor :user, :session_data, :result
  
  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data
    @result = Result.new
    @farm_reused = false
  end
  
  def call
    Rails.logger.debug I18n.t('services.plan_save_service.debug.session_data_received', data: @session_data.inspect)
    
    ActiveRecord::Base.transaction do
      # 1. マスタデータの作成・取得
      farm = create_or_get_user_farm
      @current_farm_region = farm.region

      fields = create_user_fields(farm)
      crops = create_user_crops_from_plan
      pests = copy_pests_for_region(farm.region)
      agricultural_tasks = copy_agricultural_tasks_for_region(farm.region)
      interaction_rules = copy_interaction_rules_for_region(farm.region)
      fertilizes = copy_fertilizes_for_region(farm.region)
      pesticides = copy_pesticides_for_region(farm.region)
      existing_plan = find_existing_private_plan(farm)

      if existing_plan
        Rails.logger.info "♻️ [PlanSaveService] Existing private plan detected (##{existing_plan.id}), skipping plan copy"
        @result.add_skip(:plan, existing_plan.id)
        @result.new_plan = existing_plan
        @result.success = true
        return @result
      end
      
      # 2. 計画のコピー
      new_plan = copy_cultivation_plan(farm, crops)
      
      # 3. マスタデータ間の関連付け
      establish_master_data_relationships(farm, crops, fields, pests, agricultural_tasks, fertilizes, pesticides, interaction_rules)
      
      # 4. 関連データのコピー
      copy_crop_task_schedule_blueprints_for_user_crops
      field_cultivation_map = copy_plan_relations(new_plan)
      copy_task_schedules(new_plan, field_cultivation_map)
      
      Rails.logger.info I18n.t('services.plan_save_service.messages.service_completed')
      @result.success = true
      @result.new_plan = new_plan
    end
    
    @result
  rescue InvalidTaskScheduleItemError => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.task_schedule_invalid', error: e.message) if I18n.exists?('services.plan_save_service.errors.task_schedule_invalid')
    Rails.logger.error e.backtrace.join("\n")
    raise
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.unknown_error', error: e.message)
    Rails.logger.error e.backtrace.join("\n")
    @result.error_message = e.message
    @result
  end
  
  private
  
  def copy_crop_task_schedule_blueprints_for_user_crops
    return unless @reference_crop_id_to_user_crop_id.present?
    
    @reference_crop_id_to_user_crop_id.each do |reference_crop_id, user_crop_id|
      reference_blueprints = CropTaskScheduleBlueprint
                               .where(crop_id: reference_crop_id)
                               .includes(:agricultural_task)
                               .ordered
                               .to_a
      next if reference_blueprints.empty?
      
      timestamp = Time.current
      allowed_columns = CropTaskScheduleBlueprint.column_names.map(&:to_sym)
      
      blueprint_attributes = reference_blueprints.map do |bp|
        # 参照元タスクIDの決定（sourceがあれば優先、無ければ自身のagri task）
        reference_task_id = bp.source_agricultural_task_id.presence || bp.agricultural_task_id
        mapped_user_task_id = reference_task_id ? user_agricultural_task_id_for(reference_task_id) : nil
        
        attrs = {
          crop_id: user_crop_id,
          agricultural_task_id: mapped_user_task_id,
          source_agricultural_task_id: reference_task_id,
          stage_order: bp.stage_order,
          stage_name: bp.stage_name,
          gdd_trigger: normalize_decimal(bp.gdd_trigger),
          gdd_tolerance: normalize_decimal(bp.gdd_tolerance),
          task_type: bp.task_type,
          source: bp.source,
          priority: bp.priority,
          amount: normalize_decimal(bp.amount),
          amount_unit: bp.amount_unit,
          description: bp.description,
          weather_dependency: bp.weather_dependency,
          time_per_sqm: normalize_decimal(bp.time_per_sqm),
          created_at: timestamp,
          updated_at: timestamp
        }
        
        # モデルカラムに存在するものだけ
        attrs.select { |key, _| allowed_columns.include?(key) || [:created_at, :updated_at].include?(key) }
      end
      
      CropTaskScheduleBlueprint.transaction do
        CropTaskScheduleBlueprint.where(crop_id: user_crop_id).delete_all
        CropTaskScheduleBlueprint.insert_all!(blueprint_attributes)
      end
    end
  end
  
  def normalize_decimal(value)
    return nil if value.nil?
    decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
    decimal.to_s('F')
  end
  
  def create_or_get_user_farm
    farm_id = @session_data[:farm_id] || @session_data['farm_id']
    Rails.logger.debug I18n.t('services.plan_save_service.debug.farm_id_extracted', farm_id: farm_id)
    
    reference_farm = Farm.find(farm_id)
    Rails.logger.debug I18n.t('services.plan_save_service.debug.reference_farm_found', farm_name: reference_farm.name)

    existing_farm = @user.farms.find_by(source_farm_id: reference_farm.id)
    if existing_farm
      Rails.logger.info "♻️ [PlanSaveService] Reusing existing farm: #{existing_farm.name}"
      @farm_reused = true
      @result.add_skip(:farm, existing_farm.id)
      return existing_farm
    end
    
    # 新しい農場を作成（バリデーションエラーを捕捉）
    new_farm = @user.farms.build(
      name: "#{reference_farm.name} (コピー #{Time.current.strftime('%Y%m%d_%H%M%S')})",
      latitude: reference_farm.latitude,
      longitude: reference_farm.longitude,
      region: reference_farm.region,
      is_reference: false,
      weather_location_id: reference_farm.weather_location_id,
      source_farm_id: reference_farm.id
    )
    
    unless new_farm.save
      error_message = new_farm.errors.full_messages.join(', ')
      Rails.logger.error "❌ [PlanSaveService] Farm creation failed: #{error_message}"
      # 農場件数制限のエラーの場合は特別なメッセージを返す
      if new_farm.errors.details[:user].any? { |e| e[:error] == :farm_limit_exceeded }
        raise StandardError, I18n.t('activerecord.errors.models.farm.attributes.user.farm_limit_exceeded')
      end
      raise StandardError, error_message
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.messages.farm_created', farm_name: new_farm.name)
    @farm_reused = false
    new_farm
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.farm_not_found', farm_id: farm_id)
    raise e
  end
  
  def find_existing_private_plan(farm)
    # 通年計画: farm_id × user_idのみで検索（plan_yearを除外）
    @user.cultivation_plans.where(plan_type: 'private', farm: farm).first
  end

  def create_user_crops_from_plan
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    raise StandardError, 'plan_id is required to derive crops' unless plan_id

    reference_plan = CultivationPlan.includes(cultivation_plan_crops: [crop: { crop_stages: [:temperature_requirement, :sunshine_requirement, :thermal_requirement] }]).find(plan_id)
    reference_region = reference_plan.farm&.region || @current_farm_region

    user_crops = []
    @reference_crop_id_to_user_crop_id ||= {}

    # 参照計画のcultivation_plan_cropsに含まれている作物のみをコピー
    # （20件のCrop制限を考慮し、参照計画に含まれている作物のみをコピー）
    reference_cultivation_plan_crops = reference_plan.cultivation_plan_crops.order(:id).to_a
    @ref_cpc_id_to_user_crop_id = {}

    reference_cultivation_plan_crops.each do |reference_cpc|
      reference_crop = reference_cpc.crop
      user_crop = @user.crops.find_by(source_crop_id: reference_crop.id)

      if user_crop
        @result.add_skip(:crops, user_crop.id)
        user_crops << user_crop
      else
        user_crop = @user.crops.create!(
          name: reference_crop.name,
          variety: reference_crop.variety,
          area_per_unit: reference_crop.area_per_unit,
          revenue_per_area: reference_crop.revenue_per_area,
          groups: reference_crop.groups,
          is_reference: false,
          region: reference_crop.region,
          source_crop_id: reference_crop.id
        )
        copy_crop_stages(reference_crop, user_crop)
        user_crops << user_crop
      end

      @reference_crop_id_to_user_crop_id[reference_crop.id] = user_crop.id
      @ref_cpc_id_to_user_crop_id[reference_cpc.id] = user_crop.id
    end

    Rails.logger.info I18n.t('services.plan_save_service.debug.user_crops_created', count: user_crops.count)
    user_crops
  end
  
  def create_user_fields(farm)
    if @farm_reused
      Rails.logger.info "♻️ [PlanSaveService] Skipping field creation because farm was reused"
      existing_fields = farm.fields.where(user: @user).order(:id).to_a
      existing_fields.each { |field| @result.add_skip(:fields, field.id) }
      return existing_fields
    end

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
        field_attrs[:description] = I18n.t('services.plan_save_service.messages.coordinates', lat: field_coordinates[0], lng: field_coordinates[1])
      end
      
      Rails.logger.debug "🔍 [PlanSaveService] Creating field with attrs: #{field_attrs.inspect}"
      
      new_field = farm.fields.create!(field_attrs)
      user_fields << new_field
      Rails.logger.info I18n.t('services.plan_save_service.messages.field_created', field_name: new_field.name)
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.debug.user_fields_created', count: user_fields.count)
    user_fields
  end
  
  def copy_interaction_rules_for_region(region)
    # 参照計画に含まれている作物のグループを取得
    reference_crop_groups = get_reference_crop_groups
    return [] if reference_crop_groups.empty?

    reference_scope = InteractionRule.reference.where(rule_type: 'continuous_cultivation')
    reference_scope = reference_scope.where(region: [region, nil]) if region.present?

    interaction_rules = []

    reference_scope.find_each do |reference_rule|
      # 参照計画に含まれている作物のグループに関連するルールのみをコピー
      next unless reference_crop_groups.include?(reference_rule.source_group) || 
                  reference_crop_groups.include?(reference_rule.target_group)

      existing_rule = @user.interaction_rules.find_by(source_interaction_rule_id: reference_rule.id)

      unless existing_rule
        existing_rule = @user.interaction_rules.find_by(
          rule_type: reference_rule.rule_type,
          source_group: reference_rule.source_group,
          target_group: reference_rule.target_group,
          region: reference_rule.region,
          is_reference: false
        )
      end

      if existing_rule
        if existing_rule.source_interaction_rule_id.nil?
          existing_rule.update!(source_interaction_rule_id: reference_rule.id)
        end
        @result.add_skip(:interaction_rules, existing_rule.id)
        interaction_rules << existing_rule
        next
      end

      new_rule = @user.interaction_rules.create!(
        rule_type: reference_rule.rule_type,
        source_group: reference_rule.source_group,
        target_group: reference_rule.target_group,
        impact_ratio: reference_rule.impact_ratio.to_f,
        is_directional: !!reference_rule.is_directional,
        region: reference_rule.region,
        description: reference_rule.description,
        source_interaction_rule_id: reference_rule.id
      )

      interaction_rules << new_rule
    end

    interaction_rules
  end

  def copy_pests_for_region(region)
    # 参照計画に含まれている作物のIDを取得
    reference_crop_ids = get_reference_crop_ids
    return [] if reference_crop_ids.empty?

    reference_scope = Pest.reference
    reference_scope = reference_scope.where(region: [region, nil]) if region.present?

    reference_scope = reference_scope.includes(
      :pest_temperature_profile,
      :pest_thermal_requirement,
      :pest_control_methods,
      crop_pests: :crop
    )

    user_pests = []

    @reference_pest_id_to_user_pest_id ||= {}

    reference_scope.find_each do |reference_pest|
      # 参照計画に含まれている作物に関連する害虫のみをコピー
      pest_crop_ids = reference_pest.crop_pests.pluck(:crop_id)
      next unless (pest_crop_ids & reference_crop_ids).any?

      # 既存の害虫を検索（リロードしてキャッシュの問題を回避）
      existing_pest = @user.pests.reload.find_by(source_pest_id: reference_pest.id)

      if existing_pest
        copy_pest_crop_relationships(reference_pest, existing_pest)
        @result.add_skip(:pests, existing_pest.id)
        user_pests << existing_pest
        @reference_pest_id_to_user_pest_id[reference_pest.id] = existing_pest.id
        next
      end

      new_pest = @user.pests.build(
        name: reference_pest.name,
        name_scientific: reference_pest.name_scientific,
        family: reference_pest.family,
        order: reference_pest.order,
        description: reference_pest.description,
        occurrence_season: reference_pest.occurrence_season,
        region: reference_pest.region || region,
        is_reference: false,
        source_pest_id: reference_pest.id
      )

      unless new_pest.save
        # 一意制約違反の場合、既存の害虫を取得して再利用
        error_messages = new_pest.errors.full_messages
        error_keys = new_pest.errors.keys
        
        # source_pest_idの一意制約違反、またはエラーメッセージに「Pest」と「すでに存在」が含まれる場合
        # エラーメッセージのパターン: "Pestはすでに存在します" または "Source pestはすでに存在します"
        is_uniqueness_error = error_keys.include?(:source_pest_id) || 
                              error_messages.any? { |msg| (msg.include?('Pest') || msg.include?('pest')) && (msg.include?('すでに存在') || msg.include?('already') || msg.include?('taken')) }
        
        if is_uniqueness_error
          # 再度既存の害虫を検索（並行処理などで作成された可能性がある）
          # リロードしてキャッシュの問題を回避
          existing_pest = @user.pests.reload.find_by(source_pest_id: reference_pest.id)
          if existing_pest
            copy_pest_crop_relationships(reference_pest, existing_pest)
            @result.add_skip(:pests, existing_pest.id)
            user_pests << existing_pest
            @reference_pest_id_to_user_pest_id[reference_pest.id] = existing_pest.id
            next
          else
            # 既存の害虫が見つからない場合、データ不整合の可能性があるためエラーを発生
            # （異常系はフォールバックではなくエラーを上げる）
            error_message = "Pest uniqueness constraint violation but existing pest not found: source_pest_id=#{reference_pest.id}, user_id=#{@user.id}, error_messages=#{error_messages.join(', ')}"
            Rails.logger.error "❌ [PlanSaveService] #{error_message}"
            raise StandardError, error_message
          end
        end
        
        # 一意制約違反でない場合はエラーを発生
        error_message = error_messages.join(', ')
        Rails.logger.error "❌ [PlanSaveService] Pest creation failed: #{error_message} (keys: #{error_keys.inspect})"
        raise StandardError, error_message
      end

      copy_pest_profiles(reference_pest, new_pest)
      copy_pest_control_methods(reference_pest, new_pest)
      copy_pest_crop_relationships(reference_pest, new_pest)

      user_pests << new_pest
      @reference_pest_id_to_user_pest_id[reference_pest.id] = new_pest.id
      Rails.logger.info I18n.t('services.plan_save_service.messages.pest_created', pest_name: new_pest.name)
    end

    user_pests
  end

  def copy_pest_profiles(reference_pest, new_pest)
    if (reference_profile = reference_pest.pest_temperature_profile)
      new_pest.create_pest_temperature_profile!(
        base_temperature: reference_profile.base_temperature,
        max_temperature: reference_profile.max_temperature
      )
    end

    if (reference_thermal = reference_pest.pest_thermal_requirement)
      new_pest.create_pest_thermal_requirement!(
        required_gdd: reference_thermal.required_gdd,
        first_generation_gdd: reference_thermal.first_generation_gdd
      )
    end
  end

  def copy_pest_control_methods(reference_pest, new_pest)
    reference_pest.pest_control_methods.order(:id).each do |method|
      new_pest.pest_control_methods.create!(
        method_type: method.method_type,
        method_name: method.method_name,
        description: method.description,
        timing_hint: method.timing_hint
      )
    end
  end

  def copy_pest_crop_relationships(reference_pest, new_pest)
    reference_pest.crop_pests.each do |crop_pest|
      user_crop_id = user_crop_id_for_reference_crop(crop_pest.crop_id)
      next unless user_crop_id

      CropPest.create!(
        crop_id: user_crop_id,
        pest: new_pest
      )
    end
  end

  def user_crop_id_for_reference_crop(reference_crop_id)
    @reference_crop_id_to_user_crop_id ||= {}
    return @reference_crop_id_to_user_crop_id[reference_crop_id] if @reference_crop_id_to_user_crop_id.key?(reference_crop_id)

    user_crop = @user.crops.find_by(source_crop_id: reference_crop_id)
    if user_crop
      @reference_crop_id_to_user_crop_id[reference_crop_id] = user_crop.id
      return user_crop.id
    end

    nil
  end

  def get_reference_crop_ids
    @reference_crop_id_to_user_crop_id ||= {}
    @reference_crop_id_to_user_crop_id.keys
  end

  def get_reference_crop_groups
    reference_crop_ids = get_reference_crop_ids
    return [] if reference_crop_ids.empty?

    crops = Crop.where(id: reference_crop_ids)
    # 連作ルールは作物のnameとgroupsの両方を使用する可能性があるため、両方を取得
    groups = crops.pluck(:name)
    crops.each do |crop|
      groups.concat(crop.groups) if crop.groups.present?
    end
    groups.compact.uniq
  end

  def user_pest_id_for_reference_pest(reference_pest_id)
    @reference_pest_id_to_user_pest_id ||= {}
    return @reference_pest_id_to_user_pest_id[reference_pest_id] if @reference_pest_id_to_user_pest_id.key?(reference_pest_id)

    user_pest = @user.pests.find_by(source_pest_id: reference_pest_id)
    if user_pest
      @reference_pest_id_to_user_pest_id[reference_pest_id] = user_pest.id
      return user_pest.id
    end

    nil
  end

  def copy_agricultural_tasks_for_region(region)
    # 参照計画に含まれている作物のIDを取得
    reference_crop_ids = get_reference_crop_ids
    return [] if reference_crop_ids.empty?

    reference_scope = AgriculturalTask.reference
    reference_scope = reference_scope.where(region: [region, nil]) if region.present?

    reference_scope = reference_scope.includes(crop_task_templates: :crop)

    user_tasks = []
    @reference_agricultural_task_id_to_user_task_id ||= {}

    reference_scope.find_each do |reference_task|
      # 参照計画に含まれている作物に関連する作業のみをコピー
      task_crop_ids = reference_task.crop_task_templates.pluck(:crop_id)
      next unless (task_crop_ids & reference_crop_ids).any?

      existing_task = @user.agricultural_tasks.find_by(source_agricultural_task_id: reference_task.id)

      if existing_task
        copy_agricultural_task_crop_relationships(reference_task, existing_task)
        @result.add_skip(:agricultural_tasks, existing_task.id)
        user_tasks << existing_task
        @reference_agricultural_task_id_to_user_task_id[reference_task.id] = existing_task.id
        next
      end

      new_task = @user.agricultural_tasks.build(
        name: reference_task.name,
        description: reference_task.description,
        time_per_sqm: reference_task.time_per_sqm,
        weather_dependency: reference_task.weather_dependency,
        required_tools: reference_task.required_tools ? reference_task.required_tools.dup : [],
        skill_level: reference_task.skill_level,
        task_type: reference_task.task_type,
        task_type_id: reference_task.task_type_id,
        region: reference_task.region || region,
        is_reference: false,
        source_agricultural_task_id: reference_task.id
      )

      unless new_task.save
        error_message = new_task.errors.full_messages.join(', ')
        Rails.logger.error "❌ [PlanSaveService] Agricultural task creation failed: #{error_message}"
        raise StandardError, error_message
      end

      copy_agricultural_task_crop_relationships(reference_task, new_task)

      user_tasks << new_task
      @reference_agricultural_task_id_to_user_task_id[reference_task.id] = new_task.id
      Rails.logger.info I18n.t('services.plan_save_service.messages.agricultural_task_created', task_name: new_task.name)
    end

    user_tasks
  end

  def copy_agricultural_task_crop_relationships(reference_task, new_task)
    reference_task.crop_task_templates.each do |template|
      user_crop_id = user_crop_id_for_reference_crop(template.crop_id)
      next unless user_crop_id

      ensure_crop_task_template!(crop_id: user_crop_id, task: new_task)
    end
  end

  def ensure_crop_task_template!(crop_id:, task:)
    crop = Crop.find_by(id: crop_id)
    return unless crop

    template = crop.crop_task_templates.find_or_initialize_by(agricultural_task_id: task.id)
    return if template.persisted?

    template.assign_attributes(
      name: task.name,
      description: task.description,
      time_per_sqm: task.time_per_sqm,
      weather_dependency: task.weather_dependency,
      required_tools: task.required_tools,
      skill_level: task.skill_level,
      task_type: task.task_type,
      task_type_id: task.task_type_id,
      is_reference: task.is_reference
    )
    template.save!
  end

  def copy_fertilizes_for_region(region)
    reference_scope = Fertilize.reference
    reference_scope = reference_scope.where(region: [region, nil]) if region.present?

    user_fertilizes = []

    reference_scope.find_each do |reference_fertilize|
      existing_fertilize = @user.fertilizes.find_by(source_fertilize_id: reference_fertilize.id)

      if existing_fertilize
        @result.add_skip(:fertilizes, existing_fertilize.id)
        user_fertilizes << existing_fertilize
        next
      end

      new_fertilize = @user.fertilizes.build(
        name: generate_unique_fertilize_name(reference_fertilize.name),
        n: reference_fertilize.n,
        p: reference_fertilize.p,
        k: reference_fertilize.k,
        description: reference_fertilize.description,
        package_size: reference_fertilize.package_size,
        region: reference_fertilize.region || region,
        is_reference: false,
        source_fertilize_id: reference_fertilize.id
      )

      unless new_fertilize.save
        error_message = new_fertilize.errors.full_messages.join(', ')
        Rails.logger.error "❌ [PlanSaveService] Fertilize creation failed: #{error_message}"
        raise StandardError, error_message
      end

      user_fertilizes << new_fertilize
      Rails.logger.info I18n.t('services.plan_save_service.messages.fertilize_created', fertilize_name: new_fertilize.name)
    end

    user_fertilizes
  end

  def generate_unique_fertilize_name(base_name)
    candidate = "#{base_name} (コピー)"
    return candidate unless Fertilize.exists?(name: candidate)

    suffix = 2
    loop do
      candidate = "#{base_name} (コピー #{suffix})"
      break candidate unless Fertilize.exists?(name: candidate)
      suffix += 1
    end
  end

  def copy_pesticides_for_region(region)
    reference_scope = Pesticide.reference.includes(
      :pesticide_usage_constraint,
      :pesticide_application_detail,
      :crop,
      :pest
    )
    reference_scope = reference_scope.where(region: [region, nil]) if region.present?

    user_pesticides = []

    reference_scope.find_each do |reference_pesticide|
      existing_pesticide = @user.pesticides.find_by(source_pesticide_id: reference_pesticide.id)

      if existing_pesticide
        @result.add_skip(:pesticides, existing_pesticide.id)
        user_pesticides << existing_pesticide
        next
      end

      user_crop_id = user_crop_id_for_reference_crop(reference_pesticide.crop_id)
      user_pest_id = user_pest_id_for_reference_pest(reference_pesticide.pest_id)

      unless user_crop_id && user_pest_id
        Rails.logger.warn "⚠️ [PlanSaveService] Skipping pesticide copy due to missing crop/pest mapping (pesticide_id=#{reference_pesticide.id})"
        next
      end

      new_pesticide = @user.pesticides.build(
        crop_id: user_crop_id,
        pest_id: user_pest_id,
        name: reference_pesticide.name,
        active_ingredient: reference_pesticide.active_ingredient,
        description: reference_pesticide.description,
        region: reference_pesticide.region || region,
        is_reference: false,
        source_pesticide_id: reference_pesticide.id
      )

      unless new_pesticide.save
        error_message = new_pesticide.errors.full_messages.join(', ')
        Rails.logger.error "❌ [PlanSaveService] Pesticide creation failed: #{error_message}"
        raise StandardError, error_message
      end

      copy_pesticide_usage_constraint(reference_pesticide, new_pesticide)
      copy_pesticide_application_detail(reference_pesticide, new_pesticide)

      user_pesticides << new_pesticide
      Rails.logger.info I18n.t('services.plan_save_service.messages.pesticide_created', pesticide_name: new_pesticide.name)
    end

    user_pesticides
  end

  def copy_pesticide_usage_constraint(reference_pesticide, new_pesticide)
    reference_constraint = reference_pesticide.pesticide_usage_constraint
    return unless reference_constraint

    new_pesticide.create_pesticide_usage_constraint!(
      min_temperature: reference_constraint.min_temperature,
      max_temperature: reference_constraint.max_temperature,
      max_wind_speed_m_s: reference_constraint.max_wind_speed_m_s,
      max_application_count: reference_constraint.max_application_count,
      harvest_interval_days: reference_constraint.harvest_interval_days,
      other_constraints: reference_constraint.other_constraints
    )
  end

  def copy_pesticide_application_detail(reference_pesticide, new_pesticide)
    reference_detail = reference_pesticide.pesticide_application_detail
    return unless reference_detail

    new_pesticide.create_pesticide_application_detail!(
      dilution_ratio: reference_detail.dilution_ratio,
      amount_per_m2: reference_detail.amount_per_m2,
      amount_unit: reference_detail.amount_unit,
      application_method: reference_detail.application_method
    )
  end
  
  def copy_cultivation_plan(farm, crops)
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    Rails.logger.debug I18n.t('services.plan_save_service.debug.plan_id_extracted', plan_id: plan_id)
    
    reference_plan = CultivationPlan.includes(:field_cultivations).find(plan_id)
    Rails.logger.debug I18n.t('services.plan_save_service.debug.reference_plan_found', plan_name: reference_plan.plan_name)
    
    # 参照計画が通年計画（plan_yearがnull）の場合は、plan_yearを設定せず、期間を計算
    if reference_plan.plan_year.nil?
      # 通年計画: 作付け期間からplanning_start_dateとplanning_end_dateを計算
      planning_dates = calculate_planning_dates_from_cultivations(reference_plan)
      plan_year = nil
      Rails.logger.info "📅 [PlanSaveService] Reference plan is annual planning (plan_year is null), calculated dates from cultivations"
    else
      # 既存データ（plan_yearあり）: 従来通りplan_yearから計算
      plan_year = calculate_plan_year_from_cultivations(reference_plan)
      planning_dates = CultivationPlan.calculate_planning_dates(plan_year)
      Rails.logger.info "📅 [PlanSaveService] Calculated plan_year: #{plan_year} from field_cultivations"
    end
    
    # 新しい計画を作成
    new_plan = CultivationPlan.create!(
      farm: farm,
      user: @user,
      total_area: reference_plan.total_area,
      plan_type: 'private',
      plan_year: plan_year,
      plan_name: "#{reference_plan.farm.name}の計画",
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date],
      status: 'pending',
      # 予測データをコピー（存在する場合）
      predicted_weather_data: reference_plan.predicted_weather_data
    )
    
    if reference_plan.predicted_weather_data.present?
      Rails.logger.info "✅ [PlanSaveService] Copied predicted_weather_data to new plan ##{new_plan.id}"
    else
      Rails.logger.warn "⚠️ [PlanSaveService] Reference plan has no predicted_weather_data"
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.messages.plan_created', plan_id: new_plan.id)
    new_plan
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_not_found', plan_id: plan_id)
    raise e
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_creation_failed', errors: e.message)
    raise e
  end
  
  def establish_master_data_relationships(farm, crops, fields, pests, agricultural_tasks, fertilizes, pesticides, interaction_rules)
    # 農場と圃場の関連付けは既にcreate_user_fieldsで完了
    # 作物と連作ルールの関連付けは既にcreate_interaction_rulesで完了
    
    # データ整合性チェック
    Rails.logger.info "🔍 [PlanSaveService] Data integrity check:"
    Rails.logger.info "  - Farm: #{farm.name} (ID: #{farm.id})"
    Rails.logger.info "  - Fields: #{fields.count} fields"
    Rails.logger.info "  - Crops: #{crops.count} crops"
    Rails.logger.info "  - Pests: #{pests.count} pests"
    Rails.logger.info "  - Agricultural tasks: #{agricultural_tasks.count} tasks"
    Rails.logger.info "  - Fertilizes: #{fertilizes.count} fertilizes"
    Rails.logger.info "  - Pesticides: #{pesticides.count} pesticides"
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
    
    unless pests.all?(&:persisted?)
      raise "Some pests were not properly created"
    end

    unless agricultural_tasks.all?(&:persisted?)
      raise "Some agricultural tasks were not properly created"
    end

    unless fertilizes.all?(&:persisted?)
      raise "Some fertilizes were not properly created"
    end

    unless pesticides.all?(&:persisted?)
      raise "Some pesticides were not properly created"
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
    new_crops = []
    reference_plan.cultivation_plan_crops.order(:id).each do |reference_crop_plan|
      user_crop_id = @ref_cpc_id_to_user_crop_id[reference_crop_plan.id]
      next unless user_crop_id
      
      new_crop = CultivationPlanCrop.create!(
        cultivation_plan: new_plan,
        crop_id: user_crop_id,
        name: reference_crop_plan.name,
        variety: reference_crop_plan.variety,
        area_per_unit: reference_crop_plan.area_per_unit,
        revenue_per_area: reference_crop_plan.revenue_per_area
      )
      new_crops << new_crop
      
      Rails.logger.debug "✅ [PlanSaveService] Created CultivationPlanCrop: #{new_crop.name} (variety: #{new_crop.variety})"
    end
    
    # 3. FieldCultivationを新規作成（IDマッピングを使用）
    field_cultivation_count = 0
    field_cultivation_map = {}
    reference_plan.field_cultivations.each do |reference_field_cultivation|
      # 圃場は名前でマッチング
      new_field = new_fields.find { |f| f.name == reference_field_cultivation.cultivation_plan_field.name }
      
      # 作物は登録順マッピングを使用
      mapped_user_crop_id = @ref_cpc_id_to_user_crop_id[reference_field_cultivation.cultivation_plan_crop_id]
      new_crop = new_crops.find { |c| c.crop_id == mapped_user_crop_id }
      
      unless new_field && new_crop
        Rails.logger.warn "⚠️ [PlanSaveService] Skipping FieldCultivation: field=#{new_field&.name}, crop=#{new_crop&.name}"
        next
      end
      
      new_field_cultivation = FieldCultivation.create!(
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
      field_cultivation_map[reference_field_cultivation.id] = new_field_cultivation.id
      
      Rails.logger.debug "✅ [PlanSaveService] Created FieldCultivation: #{new_field.name} + #{new_crop.name}"
    end
    
    Rails.logger.info I18n.t('services.plan_save_service.debug.plan_relations_copied', 
                            fields: new_fields.count, 
                            crops: new_crops.count, 
                            cultivations: field_cultivation_count)
    field_cultivation_map
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.plan_relations_copy_failed', errors: e.message)
    raise e
  end

  def copy_task_schedules(new_plan, field_cultivation_map)
    plan_id = @session_data[:plan_id] || @session_data['plan_id']
    reference_plan = CultivationPlan.includes(task_schedules: { task_schedule_items: :agricultural_task }).find(plan_id)

    invalid_item = TaskScheduleItem
                     .joins(:task_schedule)
                     .find_by(task_schedules: { cultivation_plan_id: plan_id }, gdd_trigger: nil)
    if invalid_item
      raise InvalidTaskScheduleItemError, "Reference TaskScheduleItem##{invalid_item.id} has nil gdd_trigger"
    end

    return if field_cultivation_map.blank?

    reference_plan.task_schedules.each do |reference_schedule|
      new_field_cultivation_id = field_cultivation_map[reference_schedule.field_cultivation_id]
      next unless new_field_cultivation_id

      new_schedule = TaskSchedule.create!(
        cultivation_plan: new_plan,
        field_cultivation_id: new_field_cultivation_id,
        category: reference_schedule.category,
        status: reference_schedule.status || 'active',
        source: 'copied_from_public_plan',
        generated_at: reference_schedule.generated_at
      )

      reference_schedule.task_schedule_items.each do |reference_item|
        mapped_task_id = mapped_agricultural_task_id(reference_item)

        if reference_item.gdd_trigger.nil?
          raise InvalidTaskScheduleItemError, "Reference TaskScheduleItem##{reference_item.id} has nil gdd_trigger"
        end

        TaskScheduleItem.create!(
          task_schedule: new_schedule,
          task_type: reference_item.task_type,
          name: reference_item.name,
          stage_name: reference_item.stage_name,
          stage_order: reference_item.stage_order,
          gdd_trigger: reference_item.gdd_trigger,
          gdd_tolerance: reference_item.gdd_tolerance,
          scheduled_date: reference_item.scheduled_date,
          priority: reference_item.priority,
          source: reference_item.source,
          weather_dependency: reference_item.weather_dependency,
          time_per_sqm: reference_item.time_per_sqm,
          amount: reference_item.amount,
          amount_unit: reference_item.amount_unit,
          status: reference_item.status.presence || TaskScheduleItem::STATUSES[:planned],
          actual_date: reference_item.actual_date,
          actual_notes: reference_item.actual_notes,
          rescheduled_at: reference_item.rescheduled_at,
          cancelled_at: reference_item.cancelled_at,
          completed_at: reference_item.completed_at,
          agricultural_task_id: mapped_task_id,
          source_agricultural_task_id: reference_item.source_agricultural_task_id || reference_item.agricultural_task&.id
        )
      end
    end
  rescue => e
    Rails.logger.error "❌ [PlanSaveService] Task schedule copy failed: #{e.message}"
    raise e
  end

  def mapped_agricultural_task_id(reference_item)
    task = reference_item.agricultural_task
    return task.id if task&.user_id == @user.id

    reference_task_id = task&.id
    return nil unless reference_task_id

    user_agricultural_task_id_for(reference_task_id)
  end

  def user_agricultural_task_id_for(reference_task_id)
    @reference_agricultural_task_id_to_user_task_id ||= {}
    return @reference_agricultural_task_id_to_user_task_id[reference_task_id] if @reference_agricultural_task_id_to_user_task_id.key?(reference_task_id)

    user_task = @user.agricultural_tasks.find_by(source_agricultural_task_id: reference_task_id)
    if user_task
      @reference_agricultural_task_id_to_user_task_id[reference_task_id] = user_task.id
      return user_task.id
    end

    nil
  end

  def requires_gdd?(_reference_item)
    true
  end
  
  # 作付け期間の平均から年度を算出（既存データ用）
  # @param reference_plan [CultivationPlan] 参照プラン
  # @return [Integer] 計画年度
  def calculate_plan_year_from_cultivations(reference_plan)
    field_cultivations = reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil)
    
    # 作付けが存在しない場合は現在の年度を返す
    if field_cultivations.empty?
      Rails.logger.info "⚠️ [PlanSaveService] No field_cultivations found, using current year: #{Date.current.year}"
      return Date.current.year
    end
    
    # 各作付けの期間の中間点を計算
    midpoints = field_cultivations.map do |cultivation|
      start_date = cultivation.start_date
      completion_date = cultivation.completion_date
      
      # 日数を計算して中間点を取得
      days_diff = (completion_date - start_date).to_i
      start_date + days_diff / 2
    end
    
    # 中間点の平均を計算（ユリウス通日を使って平均を計算）
    julian_days = midpoints.map(&:jd)
    avg_julian_day = julian_days.sum / julian_days.size
    avg_date = Date.jd(avg_julian_day.round)
    
    plan_year = avg_date.year
    
    Rails.logger.debug "📊 [PlanSaveService] Field cultivations count: #{field_cultivations.count}"
    Rails.logger.debug "📊 [PlanSaveService] Average midpoint date: #{avg_date}"
    Rails.logger.debug "📊 [PlanSaveService] Calculated plan_year: #{plan_year}"
    
    plan_year
  end

  # 作付け期間から計画期間を計算（通年計画用）
  # @param reference_plan [CultivationPlan] 参照プラン
  # @return [Hash] { start_date: Date, end_date: Date }
  def calculate_planning_dates_from_cultivations(reference_plan)
    field_cultivations = reference_plan.field_cultivations.where.not(start_date: nil, completion_date: nil)
    
    # 作付けが存在しない場合は現在年から2年間を返す
    if field_cultivations.empty?
      Rails.logger.info "⚠️ [PlanSaveService] No field_cultivations found, using default 2-year period from current date"
      return {
        start_date: Date.current.beginning_of_year,
        end_date: Date.new(Date.current.year + 1, 12, 31)
      }
    end
    
    # 全ての作付けの開始日と終了日から最小・最大を取得
    start_dates = field_cultivations.pluck(:start_date).compact
    end_dates = field_cultivations.pluck(:completion_date).compact
    
    min_start_date = start_dates.min
    max_end_date = end_dates.max
    
    # 計画期間は作付け期間の前後1年を追加
    planning_start_date = min_start_date.beginning_of_year
    planning_end_date = max_end_date.end_of_year
    
    Rails.logger.debug "📊 [PlanSaveService] Field cultivations count: #{field_cultivations.count}"
    Rails.logger.debug "📊 [PlanSaveService] Min start date: #{min_start_date}, Max end date: #{max_end_date}"
    Rails.logger.debug "📊 [PlanSaveService] Calculated planning dates: #{planning_start_date} to #{planning_end_date}"
    
    {
      start_date: planning_start_date,
      end_date: planning_end_date
    }
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

      if reference_stage.nutrient_requirement && !stage.nutrient_requirement
        NutrientRequirement.create!(
          crop_stage_id: stage.id,
          daily_uptake_n: reference_stage.nutrient_requirement.daily_uptake_n,
          daily_uptake_p: reference_stage.nutrient_requirement.daily_uptake_p,
          daily_uptake_k: reference_stage.nutrient_requirement.daily_uptake_k
        )
        Rails.logger.debug I18n.t('services.plan_save_service.messages.nutrient_requirement_copied', stage_name: stage.name)
      end
    end
  rescue => e
    Rails.logger.error I18n.t('services.plan_save_service.errors.crop_stage_copy_failed', errors: e.message)
    raise e
  end
end
