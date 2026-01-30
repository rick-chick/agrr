#! frozen_string_literal: true

class CropAiUpsertService
  Result = Struct.new(:success, :status, :body, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(user:, create_interactor:)
    @user = user
    @create_interactor = create_interactor
  end

  # 取得済みの crop_info を元に、既存作物の更新 or 新規作成を行う
  #
  # @param crop_name [String] 作物名
  # @param variety [String, nil] 品種名（任意）
  # @param crop_info [Hash] AGRR から取得した JSON パース済みハッシュ
  # @return [Result] success?/status/body を持つ結果オブジェクト
  def call(crop_name:, variety: nil, crop_info:)
    # 事前バリデーション: 件数制限をチェック（ダミーCropでバリデーション実行）
    dummy_crop = Domain::Shared::Policies::CropPolicy.build_for_create(Crop, @user, { name: 'dummy' })
    unless dummy_crop.valid?
      validation_error = dummy_crop.errors[:user].first || dummy_crop.errors[:base].first
      if validation_error
        return Result.new(
          success: false,
          status: :unprocessable_entity,
          body: { error: validation_error }
        )
      end
    end

    if crop_info['success'] == false
      error_msg = crop_info['error'] || I18n.t('api.errors.crops.fetch_failed')
      return Result.new(
        success: false,
        status: :unprocessable_entity,
        body: { error: error_msg }
      )
    end

    crop_data = crop_info['crop']
    stage_requirements = crop_info['stage_requirements']

    unless crop_data
      return Result.new(
        success: false,
        status: :unprocessable_entity,
        body: { error: I18n.t('api.errors.crops.invalid_payload') }
      )
    end

    crop_id = crop_data['crop_id'] # agrrが返すcrop_id
    Rails.logger.info "📊 [AI Crop] Retrieved data: crop_id=#{crop_id}, area=#{crop_data['area_per_unit']}, revenue=#{crop_data['revenue_per_area']}, stages=#{stage_requirements&.count || 0}"

    existing_crop = find_existing_crop_for_update(crop_id)

    if existing_crop
      update_existing_crop(existing_crop, crop_data, variety, stage_requirements)
    else
      create_new_crop(crop_name, crop_data, variety, stage_requirements)
    end
  rescue => e
    Rails.logger.error "❌ [AI Crop] Error in service: #{e.message}"
    Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
    Result.new(
      success: false,
      status: :internal_server_error,
      body: { error: I18n.t('api.errors.crops.fetch_failed_with_reason', message: e.message) }
    )
  end

  private

  def find_existing_crop_for_update(crop_id)
    return nil unless crop_id.present?

    begin
      Domain::Shared::Policies::CropPolicy.find_editable!(Crop, @user, crop_id)
    rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
      nil
    end
  end

  def update_existing_crop(existing_crop, crop_data, variety, stage_requirements)
    Rails.logger.info "🔄 [AI Crop] Existing crop found: #{existing_crop.name} (DB_ID: #{existing_crop.id}, is_reference: #{existing_crop.is_reference})"
    Rails.logger.info "🔄 [AI Crop] Updating crop with latest data from agrr"

    validate_stage_requirements!(stage_requirements)

    ActiveRecord::Base.transaction do
      existing_crop.update!(
        variety: variety.present? ? variety : (crop_data['variety'] || existing_crop.variety),
        area_per_unit: crop_data['area_per_unit'],
        revenue_per_area: crop_data['revenue_per_area'],
        groups: crop_data['groups'] || []
      )

      existing_crop.crop_stages.destroy_all
      if stage_requirements.present?
        saved_stages = save_crop_stages(existing_crop.id, stage_requirements)
        Rails.logger.info "🌱 [AI Crop] Updated #{saved_stages} stages for crop##{existing_crop.id}"
      end
    end

    Result.new(
      success: true,
      status: :ok,
      body: {
        success: true,
        crop_id: existing_crop.id,
        crop_name: existing_crop.name,
        variety: existing_crop.variety,
        area_per_unit: existing_crop.area_per_unit,
        revenue_per_area: existing_crop.revenue_per_area,
        stages_count: stage_requirements&.count || 0,
        is_reference: existing_crop.is_reference,
        message: I18n.t('api.messages.crops.updated_with_latest', name: existing_crop.name)
      }
    )
  end

  def create_new_crop(crop_name, crop_data, variety, stage_requirements)
    Rails.logger.info "🆕 [AI Crop] Creating new crop: #{crop_name} (crop_id: #{crop_data['crop_id']})"
    base_attrs = {
      name: crop_name,
      variety: variety || crop_data['variety'],
      area_per_unit: crop_data['area_per_unit'],
      revenue_per_area: crop_data['revenue_per_area'],
      groups: crop_data['groups'] || []
    }

    validate_stage_requirements!(stage_requirements)

    result = nil
    crop_entity = nil
    saved_stages = 0

    ActiveRecord::Base.transaction do
      policy_crop = Domain::Shared::Policies::CropPolicy.build_for_create(Crop, @user, base_attrs)
      attrs_for_create = base_attrs.merge(
        user_id: policy_crop.user_id,
        is_reference: policy_crop.is_reference
      )

      result = @create_interactor.call(attrs_for_create)

      unless result.success?
        Rails.logger.error "❌ [AI Crop] Failed to create: #{result.error}"
        raise ActiveRecord::Rollback
      end

      crop_entity = result.data

      if stage_requirements.present?
        saved_stages = save_crop_stages(crop_entity.id, stage_requirements)
      end
    end

    unless result&.success?
      return Result.new(
        success: false,
        status: :unprocessable_entity,
        body: { error: result&.error }
      )
    end

    Rails.logger.info "✅ [AI Crop] Created crop##{crop_entity.id}: #{crop_entity.name}"
    if stage_requirements.present?
      Rails.logger.info "🌱 [AI Crop] Saved #{saved_stages} stages for crop##{crop_entity.id}"
    end

    Result.new(
      success: true,
      status: :created,
      body: {
        success: true,
        crop_id: crop_entity.id,
        crop_name: crop_entity.name,
        variety: crop_entity.variety,
        area_per_unit: crop_entity.area_per_unit,
        revenue_per_area: crop_entity.revenue_per_area,
        stages_count: stage_requirements&.count || 0,
        message: I18n.t('api.messages.crops.created_by_ai', name: crop_entity.name)
      }
    )
  end

  def save_crop_stages(crop_id, stages_data)
    saved_count = 0

    stages_data.each do |stage_requirement|
      stage_info = stage_requirement['stage']
      raise ArgumentError, 'stage information is required' unless stage_info
      if stage_info['order'].nil? || stage_info['order'].to_s.strip.empty?
        raise ArgumentError, 'stage order is required'
      end

      stage = ::CropStage.create!(
        crop_id: crop_id,
        name: stage_info['name'],
        order: stage_info['order']
      )

      if stage_requirement['temperature'].present?
        temp_data = stage_requirement['temperature']
        ::TemperatureRequirement.create!(
          crop_stage_id: stage.id,
          base_temperature: temp_data['base_temperature'],
          optimal_min: temp_data['optimal_min'],
          optimal_max: temp_data['optimal_max'],
          low_stress_threshold: temp_data['low_stress_threshold'],
          high_stress_threshold: temp_data['high_stress_threshold'],
          frost_threshold: temp_data['frost_threshold'],
          sterility_risk_threshold: temp_data['sterility_risk_threshold']
        )
      end

      if stage_requirement['sunshine'].present?
        sunshine_data = stage_requirement['sunshine']
        ::SunshineRequirement.create!(
          crop_stage_id: stage.id,
          minimum_sunshine_hours: sunshine_data['minimum_sunshine_hours'],
          target_sunshine_hours: sunshine_data['target_sunshine_hours']
        )
      end

      if stage_requirement['thermal'].present?
        thermal_data = stage_requirement['thermal']
        ::ThermalRequirement.create!(
          crop_stage_id: stage.id,
          required_gdd: thermal_data['required_gdd']
        )
      end

      if stage_requirement['nutrients'].present?
        nutrients_data = stage_requirement['nutrients']
        daily_uptake = nutrients_data['daily_uptake']
        if daily_uptake.present?
          ::NutrientRequirement.create!(
            crop_stage_id: stage.id,
            daily_uptake_n: daily_uptake['N'],
            daily_uptake_p: daily_uptake['P'],
            daily_uptake_k: daily_uptake['K']
          )
        end
      end

      saved_count += 1
      Rails.logger.debug "  🌱 Stage #{stage.order}: #{stage.name} (ID: #{stage.id})"
    end

    saved_count
  end

  def validate_stage_requirements!(stage_requirements)
    return unless stage_requirements.present?

    stage_requirements.each do |stage_requirement|
      stage_info = stage_requirement['stage']
      raise ArgumentError, 'stage information is required' unless stage_info
      if stage_info['order'].nil? || stage_info['order'].to_s.strip.empty?
        raise ArgumentError, 'stage order is required'
      end
    end
  end
end

