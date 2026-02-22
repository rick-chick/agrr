# frozen_string_literal: true

class CropsController < ApplicationController
  include DeletionUndoFlow
  include HtmlCrudResponder
  before_action :set_crop, only: [:edit, :update, :destroy, :generate_task_schedule_blueprints, :toggle_task_template]
  before_action :authenticate_admin!, only: [:generate_task_schedule_blueprints]

  # GET /crops
  def index
    presenter = Presenters::Html::Crop::CropListHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropListInteractor.new(
      output_port: presenter,
      gateway: crop_gateway,
      user_id: current_user.id,
      logger: logger_gateway
    )

    interactor.call
  rescue StandardError => e
    redirect_to root_path, alert: e.message
  end

  # GET /crops/:id
  def show
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(view: self)
    interactor = Domain::Crop::Interactors::CropDetailInteractor.new(
      output_port: presenter,
      gateway: crop_gateway,
      user_id: current_user.id,
      logger: logger_gateway
    )
    interactor.call(params[:id])
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
  rescue StandardError => e
    redirect_to crops_path, alert: e.message
  end

  # GET /crops/new
  def new
    @crop = Crop.new
  end

  # GET /crops/:id/edit
  def edit
    @crop.crop_stages.each do |stage|
      stage.build_nutrient_requirement unless stage.nutrient_requirement
    end
  end

  # POST /crops
  def create
    is_reference = crop_params[:is_reference] || false
    if is_reference && !admin_user?
      return redirect_to crops_path, alert: I18n.t('crops.flash.reference_only_admin')
    end

    @input_dto = Domain::Crop::Dtos::CropCreateInputDto.from_hash({ crop: crop_params.to_h.symbolize_keys })
    presenter = Presenters::Html::Crop::CropCreateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropCreateInteractor.new(
      output_port: presenter,
      gateway: crop_gateway,
      user_id: current_user.id
    )

    interactor.call(@input_dto)
  rescue StandardError => e
    @crop = Crop.new(crop_params.to_h.symbolize_keys)
    @crop.valid? # エラーをセットするためにバリデーションを実行
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  # PATCH/PUT /crops/:id
  def update
    if crop_params.key?(:is_reference) && !admin_user?
      return redirect_to crop_path(@crop), alert: I18n.t('crops.flash.reference_flag_admin_only')
    end

    @input_dto = Domain::Crop::Dtos::CropUpdateInputDto.from_hash({ crop: crop_params.to_h.symbolize_keys }, params[:id])
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: self)

    interactor = Domain::Crop::Interactors::CropUpdateInteractor.new(
      output_port: presenter,
      gateway: crop_gateway,
      user_id: current_user.id,
      logger: logger_gateway
    )

    interactor.call(@input_dto)
  rescue StandardError => e
    @crop.assign_attributes(crop_params.to_h.symbolize_keys)
    @crop.valid? # エラーをセットするためにバリデーションを実行
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /crops/:id
  def destroy
    respond_to do |format|
      format.html do
        presenter = Presenters::Html::Crop::CropDestroyHtmlPresenter.new(view: self)
        interactor = Domain::Crop::Interactors::CropDestroyInteractor.new(
          output_port: presenter,
          gateway: crop_gateway,
          user_id: current_user.id,
          logger: logger_gateway,
          translator: translator
        )
        interactor.call(params[:id])
      rescue Domain::Shared::Policies::PolicyPermissionDenied
        redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
      end

      format.json do
        schedule_deletion_with_undo(
          record: @crop,
          toast_message: I18n.t('crops.undo.toast', name: @crop.name),
          fallback_location: crops_path,
          in_use_message_key: 'crops.flash.cannot_delete_in_use',
          delete_error_message_key: 'crops.flash.delete_error'
        )
      end
    end
  end

  def generate_task_schedule_blueprints
    service = CropTaskScheduleBlueprintCreateService.new
    service.regenerate!(crop: @crop)
    redirect_to crop_path(@crop), notice: I18n.t('crops.flash.task_schedule_blueprints_generated')
  rescue CropTaskScheduleBlueprintCreateService::MissingAgriculturalTasksError,
         CropTaskScheduleBlueprintCreateService::GenerationFailedError => e
    redirect_to crop_path(@crop), alert: e.message
  rescue StandardError => e
    Rails.logger.error("❌ [CropsController] Failed to generate blueprints for Crop##{@crop.id}: #{e.class} #{e.message}")
    Rails.logger.error(e.full_message)
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.task_schedule_blueprints_failed')
  end

  # POST /crops/:id/toggle_task_template
  def toggle_task_template
    agricultural_task = AgriculturalTask.find(params[:agricultural_task_id])
    
    Rails.logger.info("🔍 [CropsController] toggle_task_template called: crop_id=#{@crop.id}, task_id=#{agricultural_task.id}")
    
    # agricultural_task_idでチェック
    existing_template = @crop.crop_task_templates.where(
      agricultural_task: agricultural_task
    ).first
    
    if existing_template
      # テンプレートを削除
      Rails.logger.info("🗑️ [CropsController] Deleting template: template_id=#{existing_template.id}")
      
      # 対応するブループリントを削除（agricultural_task_idに関連するすべてのブループリント）
      related_blueprints = @crop.crop_task_schedule_blueprints
                                 .where(agricultural_task: agricultural_task)
      if related_blueprints.any?
        Rails.logger.info("🗑️ [CropsController] Deleting #{related_blueprints.count} blueprints for agricultural_task_id=#{agricultural_task.id}")
        Rails.logger.info("🗑️ [CropsController] Blueprint sources: #{related_blueprints.pluck(:source).join(', ')}")
        related_blueprints.destroy_all
      end
      
      existing_template.destroy
      # テンプレート削除後にアソシエーションを再読み込み
      @crop.crop_task_templates.reload
      Rails.logger.info("✅ [CropsController] Template deleted successfully")
    else
      # テンプレートを作成
      Rails.logger.info("➕ [CropsController] Creating new template")
      @crop.crop_task_templates.create!(
        agricultural_task: agricultural_task,
        name: agricultural_task.name,
        description: agricultural_task.description,
        time_per_sqm: agricultural_task.time_per_sqm,
        weather_dependency: agricultural_task.weather_dependency,
        required_tools: agricultural_task.required_tools,
        skill_level: agricultural_task.skill_level
      )
      Rails.logger.info("✅ [CropsController] Template created successfully")
      
      # 対応するブループリントを作成
      create_blueprint_for_template(agricultural_task)
    end
    
    # Turbo Stream用に変数を再取得
    @available_agricultural_tasks = available_agricultural_tasks_for_crop(@crop)
    @selected_task_ids = selected_task_ids_for_crop(@crop)
    @task_schedule_blueprints = @crop.crop_task_schedule_blueprints
                                      .includes(:agricultural_task)
                                      .ordered
    
    Rails.logger.info("📊 [CropsController] Updated state: available_tasks=#{@available_agricultural_tasks.size}, selected_ids=#{@selected_task_ids.inspect}")
    
    respond_to do |format|
      format.turbo_stream do
        Rails.logger.info("📡 [CropsController] Rendering turbo_stream response")
        render :toggle_task_template
      end
      format.html { redirect_to crop_path(@crop) }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.task_not_found')
  rescue StandardError => e
    Rails.logger.error("❌ [CropsController] Failed to toggle task template: #{e.class} #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.toggle_task_template_failed')
  end

  private

  def set_crop
    action = params[:action].to_sym

    # まず権限チェック（編集系か閲覧系かで分岐）
    authorized_crop =
      if action.in?([:edit, :update, :destroy, :generate_task_schedule_blueprints, :toggle_task_template])
        Domain::Shared::Policies::CropPolicy.find_editable!(Crop, current_user, params[:id])
      else
        Domain::Shared::Policies::CropPolicy.find_visible!(Crop, current_user, params[:id])
      end

    # 付加情報を preload したレコードとして再取得
    @crop = Crop.includes(
      crop_stages: [:temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement],
      agricultural_tasks: [],
      crop_task_templates: [:agricultural_task],
      crop_task_schedule_blueprints: [:agricultural_task]
    ).find(authorized_crop.id)
  rescue Domain::Shared::Policies::PolicyPermissionDenied
    redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
  rescue ActiveRecord::RecordNotFound
    redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
  end

  def crop_params
    permitted = [
      :name, 
      :variety, 
      :is_reference,
      :area_per_unit,
      :revenue_per_area,
      :groups,
      crop_stages_attributes: [
        :id,
        :name,
        :order,
        :_destroy,
        temperature_requirement_attributes: [
          :id,
          :base_temperature,
          :optimal_min,
          :optimal_max,
          :low_stress_threshold,
          :high_stress_threshold,
          :frost_threshold,
          :sterility_risk_threshold,
          :max_temperature,
          :_destroy
        ],
        thermal_requirement_attributes: [
          :id,
          :required_gdd,
          :_destroy
        ],
        sunshine_requirement_attributes: [
          :id,
          :minimum_sunshine_hours,
          :target_sunshine_hours,
          :_destroy
        ],
        nutrient_requirement_attributes: [
          :id,
          :daily_uptake_n,
          :daily_uptake_p,
          :daily_uptake_k,
          :_destroy
        ]
      ]
    ]
    
    # 管理者のみregionを許可
    permitted << :region if admin_user?
    
    params.require(:crop).permit(*permitted)
  end

  # 作物に利用可能な農業タスクを取得
  def available_agricultural_tasks_for_crop(crop)
    # ユーザ作物であればそのユーザの作業のみ
    if !crop.is_reference && crop.user_id.present?
      tasks = AgriculturalTask.user_owned.where(user_id: crop.user_id)
      # 地域が設定されていればその地域も条件に追加
      tasks = tasks.where(region: crop.region) if crop.region.present?
      return tasks.order(:name)
    end
    
    # 参照作物であれば参照作業のみ
    if crop.is_reference
      tasks = AgriculturalTask.reference
      # 地域が設定されていればその地域も条件に追加
      tasks = tasks.where(region: crop.region) if crop.region.present?
      return tasks.order(:name)
    end
    
    # どちらでもない場合は空のコレクション
    AgriculturalTask.none
  end

  # 作物に既にテンプレートとして登録されているタスクIDを取得
  def selected_task_ids_for_crop(crop)
    crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
  end

  # テンプレートからブループリントを作成
  def create_blueprint_for_template(agricultural_task)
    # 既存のブループリントの最大stage_orderとpriorityを取得
    existing_blueprints = @crop.crop_task_schedule_blueprints
    max_stage_order = existing_blueprints.maximum(:stage_order) || -1
    max_priority = existing_blueprints.maximum(:priority) || 0

    # 同じagricultural_task_idで既にブループリントが存在する場合は作成しない
    existing_blueprint = existing_blueprints.find_by(
      agricultural_task: agricultural_task,
      source: 'manual'
    )
    if existing_blueprint
      Rails.logger.info("ℹ️ [CropsController] Blueprint already exists: blueprint_id=#{existing_blueprint.id}")
      return existing_blueprint
    end

    # テンプレートを取得
    template = @crop.crop_task_templates.find_by(agricultural_task: agricultural_task)
    
    # ブループリントを作成
    blueprint = @crop.crop_task_schedule_blueprints.create!(
      agricultural_task: agricultural_task,
      stage_order: max_stage_order + 1,
      gdd_trigger: BigDecimal('0.0'),
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: 'manual',
      priority: max_priority + 1,
      description: template&.description || agricultural_task.description || agricultural_task.name,
      weather_dependency: template&.weather_dependency || agricultural_task.weather_dependency,
      time_per_sqm: template&.time_per_sqm || agricultural_task.time_per_sqm,
      stage_name: nil,
      gdd_tolerance: nil,
      amount: nil,
      amount_unit: nil
    )
    
    Rails.logger.info("✅ [CropsController] Blueprint created: blueprint_id=#{blueprint.id}, stage_order=#{blueprint.stage_order}, priority=#{blueprint.priority}")
    blueprint
  rescue StandardError => e
    Rails.logger.error("❌ [CropsController] Failed to create blueprint: #{e.class} #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  def crop_gateway
    @crop_gateway ||= Adapters::Crop::Gateways::CropMemoryGateway.new
  end

  def logger_gateway
    @logger_gateway ||= Adapters::Logger::Gateways::RailsLoggerGateway.new
  end
end

