# frozen_string_literal: true

class CropsController < ApplicationController
  before_action :set_crop, only: [:show, :edit, :update, :destroy, :generate_task_schedule_blueprints, :toggle_task_template]
  before_action :authenticate_admin!, only: [:generate_task_schedule_blueprints]

  # GET /crops
  def index
    # 管理者は参照作物も表示、一般ユーザーは自分の作物のみ
    if admin_user?
      @crops = Crop.where("is_reference = ? OR user_id = ?", true, current_user.id).recent
    else
      @crops = Crop.where(user_id: current_user.id).recent
    end
  end

  # GET /crops/:id
  def show
    # 閲覧可能な農業タスクを取得（管理者は参照タスクと自身のタスク、一般ユーザーは自身のタスクのみ）
    @task_schedule_blueprints = @crop.crop_task_schedule_blueprints
                                      .includes(:agricultural_task)
                                      .ordered

    # 利用可能な農業タスクを取得
    @available_agricultural_tasks = available_agricultural_tasks_for_crop(@crop)
    # 既にテンプレートとして登録されているタスクIDを取得
    @selected_task_ids = selected_task_ids_for_crop(@crop)
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

    @crop = Crop.new(crop_params)
    @crop.user_id = nil if is_reference
    @crop.user_id ||= current_user.id

    # groupsをカンマ区切りテキストから配列に変換
    if params.dig(:crop, :groups).is_a?(String)
      @crop.groups = params[:crop][:groups].split(',').map(&:strip).reject(&:blank?)
    end

    if @crop.save
      redirect_to crop_path(@crop), notice: I18n.t('crops.flash.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /crops/:id
  def update
    if crop_params.key?(:is_reference) && !admin_user?
      return redirect_to crop_path(@crop), alert: I18n.t('crops.flash.reference_flag_admin_only')
    end

    # groupsをカンマ区切りテキストから配列に変換
    if params.dig(:crop, :groups).is_a?(String)
      @crop.groups = params[:crop][:groups].split(',').map(&:strip).reject(&:blank?)
    end

    if @crop.update(crop_params)
      redirect_to crop_path(@crop), notice: I18n.t('crops.flash.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /crops/:id
  def destroy
    event = DeletionUndo::Manager.schedule(
      record: @crop,
      actor: current_user,
      toast_message: I18n.t('crops.undo.toast', name: @crop.name)
    )

    render_deletion_undo_response(
      event,
      fallback_location: crops_path
    )
  rescue ActiveRecord::InvalidForeignKey => e
    message =
      if e.message.include?('cultivation_plan_crops')
        I18n.t('crops.flash.cannot_delete_in_use.plan')
      elsif e.message.include?('field_cultivations')
        I18n.t('crops.flash.cannot_delete_in_use.field')
      else
        I18n.t('crops.flash.cannot_delete_in_use.other')
      end

    render_deletion_failure(
      message: message,
      fallback_location: crops_path
    )
  rescue ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('crops.flash.cannot_delete_in_use.other'),
      fallback_location: crops_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('crops.flash.delete_error', message: e.message),
      fallback_location: crops_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('crops.flash.delete_error', message: e.message),
      fallback_location: crops_path
    )
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
    
    # agricultural_task_idとsource_agricultural_task_idの両方をチェック
    existing_template = @crop.crop_task_templates.where(
      agricultural_task: agricultural_task
    ).or(
      @crop.crop_task_templates.where(source_agricultural_task_id: agricultural_task.id)
    ).first
    
    if existing_template
      # テンプレートを削除
      existing_template.destroy
    else
      # テンプレートを作成
      @crop.crop_task_templates.create!(
        agricultural_task: agricultural_task,
        name: agricultural_task.name,
        description: agricultural_task.description,
        time_per_sqm: agricultural_task.time_per_sqm,
        weather_dependency: agricultural_task.weather_dependency,
        required_tools: agricultural_task.required_tools,
        skill_level: agricultural_task.skill_level
      )
    end
    
    # Turbo Stream用に変数を再取得
    @available_agricultural_tasks = available_agricultural_tasks_for_crop(@crop)
    @selected_task_ids = selected_task_ids_for_crop(@crop)
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to crop_path(@crop) }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.task_not_found')
  rescue StandardError => e
    Rails.logger.error("❌ [CropsController] Failed to toggle task template: #{e.class} #{e.message}")
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.toggle_task_template_failed')
  end

  private

  def set_crop
    @crop = Crop.includes(
      crop_stages: [:temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement],
      agricultural_tasks: [],
      crop_task_templates: [:agricultural_task],
      crop_task_schedule_blueprints: [:agricultural_task]
    ).find(params[:id])
    
    # アクションに応じた権限チェック
    action = params[:action].to_sym
    
    if action.in?([:edit, :update, :destroy])
      # 編集・更新・削除は以下の場合のみ許可
      # - 管理者（すべての作物を編集可能）
      # - ユーザー作物の所有者
      unless admin_user? || (!@crop.is_reference && @crop.user_id == current_user.id)
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    elsif action == :show
      # 詳細表示は以下の場合に許可
      # - 参照作物（誰でも閲覧可能）
      # - 自分の作物
      # - 管理者
      unless @crop.is_reference || @crop.user_id == current_user.id || admin_user?
        redirect_to crops_path, alert: I18n.t('crops.flash.no_permission')
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to crops_path, alert: I18n.t('crops.flash.not_found')
  end

  def crop_params
    params.require(:crop).permit(
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
    )
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
  # agricultural_task_idとsource_agricultural_task_idの両方を考慮
  def selected_task_ids_for_crop(crop)
    # 1回のクエリで両方のカラムを取得
    templates = crop.crop_task_templates
                    .pluck(:agricultural_task_id, :source_agricultural_task_id)
    
    # 両方のIDを1つの配列にまとめて、nilを除外してユニークにする
    templates.flat_map { |task_id, source_id| [task_id, source_id] }.compact.uniq
  end
end


