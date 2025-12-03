# frozen_string_literal: true

class PlansController < ApplicationController
  include CultivationPlanManageable
  include JobExecution
  include WeatherDataManagement
  
  before_action :authenticate_user!
  before_action :set_plan, only: [:optimize, :destroy, :copy]
  layout 'application'
  
  # Concern設定
  self.plan_type = 'private'
  self.session_key = :plan_data
  self.redirect_path_method = :plans_path
  
  # 計画一覧（農場別）
  def index
    @vm = Plans::IndexPresenter.new(current_user: current_user)
    @plans_by_farm = @vm.plans_by_farm
    Rails.logger.debug "📅 [Plans#index] User: #{current_user.id}, Plans by farm: #{@plans_by_farm.keys.inspect}"
  end
  
  # Step 1: 農場選択
  def new
    @vm = Plans::NewPresenter.new(current_user: current_user)
    @farms = @vm.farms
    @default_plan_name = @vm.default_plan_name
    Rails.logger.debug "🌍 [Plans#new] User: #{current_user.id}, Farms: #{@farms.count}"
  end
  
  # Step 2: 作物選択
  def select_crop
    unless params[:farm_id].present?
      redirect_to new_plan_path, alert: I18n.t('plans.errors.select_farm') and return
    end

    @vm = Plans::SelectCropPresenter.new(
      current_user: current_user,
      farm_id: params[:farm_id]
    )
    @farm = @vm.farm
    @plan_name = @vm.plan_name
    @crops = @vm.crops
    @fields = @vm.fields
    @total_area = @vm.total_area
    
    # セッションに保存（plan_yearは使用しない - 年度という概念は削除されました）
    session[self.class.session_key] = {
      farm_id: @farm.id,
      plan_name: @plan_name,
      total_area: @total_area
    }
    
    Rails.logger.debug "✅ [Plans#select_crop] Session saved: #{session[:plan_data].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to new_plan_path, alert: I18n.t('plans.errors.farm_not_found')
  end
  
  # Step 3: 計画作成（最適化はしない）
  def create
    return unless validate_session_data
    
    farm = find_farm_from_session
    crops = find_selected_crops
    
    if crops.empty?
      # Turbo対応: フォールバックせず同画面を422で再描画
      @vm = Plans::SelectCropPresenter.new(
        current_user: current_user,
        farm_id: session_data[:farm_id]
      )
      @farm = @vm.farm
      @plan_name = @vm.plan_name
      @crops = @vm.crops
      @fields = @vm.fields
      @total_area = @vm.total_area
      flash.now[:alert] = I18n.t('plans.errors.select_crop')
      return render :select_crop, status: :unprocessable_entity
    end
    
    # 既存の計画があるかチェック（通年計画: farm_id × user_idのみで検索）
    # @deprecated plan_yearの参照は後方互換性のため残していますが、新しい計画ではplan_yearはnilです。
    existing_plan = find_existing_plan(farm)
    if existing_plan
      Rails.logger.info "⚠️ [PlansController#create] Existing plan found: #{existing_plan.id}"
      if existing_plan.plan_year.present?
        redirect_to plan_path(existing_plan), alert: I18n.t('plans.errors.plan_already_exists', year: existing_plan.plan_year)
      else
        redirect_to plan_path(existing_plan), alert: I18n.t('plans.errors.plan_already_exists_annual')
      end
      return
    end
    
    result = create_cultivation_plan_with_jobs(farm, crops)
    redirect_to_optimizing(result.cultivation_plan.id)
  rescue ActiveRecord::RecordNotFound
    redirect_to new_plan_path, alert: I18n.t('plans.errors.restart')
  end
  
  # 計画の最適化を実行
  def optimize
    # 既に最適化中の場合はスキップ（完了は許可）
    if @plan.status_optimizing?
      redirect_to plan_path(@plan), alert: I18n.t('plans.errors.already_optimized') and return
    end
    
    # 最適化は計画作成時に既に実行されているため、進捗画面にリダイレクト
    redirect_to optimizing_plan_path(@plan.id), notice: I18n.t('plans.messages.optimization_started')
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
  
  # Step 4: 最適化進捗画面
  def optimizing
    Rails.logger.info "🎯 [PlansController#optimizing] Starting optimizing view for plan: #{params[:id]}"
    @vm = Plans::OptimizingPresenter.new(plan_id: params[:id])
    handle_optimizing(force_weather_only: true)
  end
  
  # Step 5: 計画詳細（結果表示）
  def show
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # 最適化中の場合のみ進捗画面へ
    redirect_to optimizing_plan_path(@cultivation_plan.id) if @cultivation_plan.status_optimizing?
    @vm = Plans::ShowPresenter.new(cultivation_plan: @cultivation_plan)
  end
  
  # @deprecated 年度という概念は削除されました。コピー機能は無効化されています。
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    source_plan = @plan
    
    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、
    # コピー機能は無効化されました（通年計画と年度ベースの計画の両方）
    # 既存の年度ベースの計画は後方互換性のために保持されますが、
    # 新しい計画は通年計画として作成されるため、コピー機能は不要です
    redirect_to plans_path, alert: I18n.t('plans.errors.copy_not_available_for_annual_planning') and return
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
  
  # 計画削除
  def destroy
    plan = @plan

    event = DeletionUndo::Manager.schedule(
      record: plan,
      actor: current_user,
      toast_message: I18n.t('plans.undo.toast', name: plan.display_name)
    )

    render_deletion_undo_response(
      event,
      fallback_location: plans_path
    )
  rescue ActiveRecord::RecordNotFound
    render_deletion_failure(
      message: I18n.t('plans.errors.not_found'),
      fallback_location: plans_path,
      status: :not_found
    )
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    render_deletion_failure(
      message: I18n.t('plans.errors.delete_failed'),
      fallback_location: plans_path
    )
  rescue DeletionUndo::Error => e
    render_deletion_failure(
      message: I18n.t('plans.errors.delete_error', message: e.message),
      fallback_location: plans_path
    )
  rescue StandardError => e
    render_deletion_failure(
      message: I18n.t('plans.errors.delete_error', message: e.message),
      fallback_location: plans_path
    )
  end
  
  private
  
  # Concernで実装すべきメソッド
  
  def set_plan
    @plan = PlanPolicy.find_private_owned!(current_user, params[:id])
  end
  
  def find_cultivation_plan_scope
    PlanPolicy.private_scope(current_user)
  end
  
  def select_crop_redirect_path
    :select_crop_plans_path
  end
  
  def optimizing_redirect_path
    :optimizing_plan_path
  end
  
  def completion_redirect_path
    :plan_path
  end
  
  def channel_class
    PlansOptimizationChannel
  end
  
  # JobExecutionで使用する遷移先パス
  def job_completion_redirect_path
    plan_path(@cultivation_plan || CultivationPlan.find(session_data[:plan_id]))
  end

  def create_job_instances_for_plans(cultivation_plan_id, channel_class)
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    farm = cultivation_plan.farm
    
    # 天気データ取得パラメータを計算
    weather_params = calculate_weather_data_params(farm.weather_location)
    
    # FetchWeatherDataJobのインスタンスを作成し、引数を設定
    weather_job = FetchWeatherDataJob.new
    weather_job.latitude = farm.latitude
    weather_job.longitude = farm.longitude
    weather_job.start_date = weather_params[:start_date]
    weather_job.end_date = weather_params[:end_date]
    weather_job.farm_id = farm.id
    weather_job.cultivation_plan_id = cultivation_plan_id
    weather_job.channel_class = channel_class
    
    # 天気予測の日数を調整（終了日を考慮）
    predict_days = calculate_predict_days(weather_params[:end_date])
    
    # WeatherPredictionJobのインスタンスを作成し、引数を設定
    prediction_job = WeatherPredictionJob.new
    prediction_job.cultivation_plan_id = cultivation_plan_id
    prediction_job.channel_class = channel_class
    prediction_job.predict_days = predict_days
    
    # 最適化ジョブ（公開計画と同様に最後まで実施）
    optimization_job = OptimizationJob.new
    optimization_job.cultivation_plan_id = cultivation_plan_id
    optimization_job.channel_class = channel_class

    # private plan の場合、blueprint が全作物に存在するときのみ作業予定生成ジョブを追加
    job_chain = [
      weather_job,
      prediction_job,
      optimization_job
    ]

    crops = cultivation_plan.cultivation_plan_crops.includes(:crop).map(&:crop)
    all_crops_have_blueprints = crops.present? && crops.all? { |crop| crop.crop_task_schedule_blueprints.exists? }

    if all_crops_have_blueprints
      Rails.logger.info "🧩 [PlansController] Blueprints found for all crops. Enqueue TaskScheduleGenerationJob."
      task_schedule_job = TaskScheduleGenerationJob.new
      task_schedule_job.cultivation_plan_id = cultivation_plan_id
      task_schedule_job.channel_class = channel_class
      job_chain << task_schedule_job
      # 作業予定生成後も最終フェーズ更新と完了を保証
      finalize_job = PlanFinalizeJob.new
      finalize_job.cultivation_plan_id = cultivation_plan_id
      finalize_job.channel_class = channel_class
      job_chain << finalize_job
    else
      Rails.logger.info "ℹ️ [PlansController] No blueprints for some or all crops. Skipping schedule generation and finalizing plan."
      finalize_job = PlanFinalizeJob.new
      finalize_job.cultivation_plan_id = cultivation_plan_id
      finalize_job.channel_class = channel_class
      job_chain << finalize_job
    end

    job_chain
  end

  # 栽培計画作成とジョブ実行
  def create_cultivation_plan_with_jobs(farm, crops)
    creator_params = build_creator_params(farm, crops)
    result = CultivationPlanCreator.new(**creator_params).call
    
    # エラーハンドリング: 計画作成に失敗した場合
    unless result.success? && result.cultivation_plan
      Rails.logger.error "❌ [PlansController#create] CultivationPlan creation failed: #{result.errors.join(', ')}"
      raise ActiveRecord::RecordInvalid.new(result.cultivation_plan || CultivationPlan.new)
    end
    
    Rails.logger.info "✅ [PlansController#create] CultivationPlan created: #{result.cultivation_plan.id}"
    session[self.class.session_key] = { plan_id: result.cultivation_plan.id }
    
    # ジョブチェーンを非同期実行
    job_instances = create_job_instances_for_plans(result.cultivation_plan.id, PlansOptimizationChannel)
    execute_job_chain_async(job_instances)
    
    result
  end

  # 作成者パラメータを構築
  def build_creator_params(farm, crops)
    # 通年計画: plan_yearを使わずにplanning_start_dateとplanning_end_dateを設定
    # @deprecated 年度という概念は削除されました。plan_yearは常にnilです。
    plan_name = session_data[:plan_name].presence || farm.name
    # デフォルトは現在年から2年間
    planning_start_date = Date.current.beginning_of_year
    planning_end_date = Date.new(Date.current.year + 1, 12, 31)
    session_id = session.id.to_s
    
    Rails.logger.info "🔑 [PlansController#create] Using session_id: #{session_id}"
    Rails.logger.info "👤 [PlansController#create] Current user: #{current_user&.name} (#{current_user&.id})"
    Rails.logger.info "🏡 [PlansController#create] Farm: #{farm.name} (#{farm.id})"
    Rails.logger.info "🌾 [PlansController#create] Crops: #{crops.count} crops"
    Rails.logger.info "📊 [PlansController#create] Session data: #{session_data.inspect}"
    Rails.logger.info "📅 [PlansController#create] Planning dates: #{planning_start_date} to #{planning_end_date}"
    
    {
      farm: farm,
      total_area: session_data[:total_area].presence || farm.fields.sum(:area),
      crops: crops,
      user: current_user,
      session_id: session_id,
      plan_type: self.class.plan_type,
      plan_year: nil, # @deprecated 年度という概念は削除されました。常にnilです。
      plan_name: plan_name,
      planning_start_date: planning_start_date,
      planning_end_date: planning_end_date
    }
  end

  # セッションデータの検証
  def validate_session_data
    Rails.logger.info "🔍 [PlansController#create] Validating session data (minimal): #{session_data.inspect}"
    # 通年計画: plan_yearのチェックを削除（年度という概念は削除されました）
    required_present = session_data[:farm_id].present?
    unless required_present
      Rails.logger.warn "⚠️ [PlansController#create] Missing minimal session data"
      redirect_to new_plan_path, alert: I18n.t('plans.errors.restart')
      return false
    end
    Rails.logger.info "✅ [PlansController#create] Minimal session data validation passed"
    true
  end


  # セッションから農場を取得
  def find_farm_from_session
    farm_id = session_data[:farm_id]
    Rails.logger.info "🏡 [PlansController#create] Finding farm with ID: #{farm_id}"
    
    unless farm_id
      Rails.logger.warn "⚠️ [PlansController#create] No farm_id in session data"
      raise ActiveRecord::RecordNotFound, "Farm ID not found in session"
    end
    
    farm = current_user.farms.find(farm_id)
    Rails.logger.info "✅ [PlansController#create] Found farm: #{farm.name} (#{farm.id})"
    farm
  end

  # 既存の計画を検索（通年計画: farm_id × user_idのみで検索）
  # @deprecated plan_yearの参照は後方互換性のため残していますが、新しい計画ではplan_yearはnilです。
  def find_existing_plan(farm)
    Rails.logger.info "🔍 [PlansController#create] Checking for existing plan: farm_id=#{farm.id}, user_id=#{current_user.id}"
    
    existing_plan = current_user.cultivation_plans
      .plan_type_private
      .where(farm: farm)
      .first
    
    if existing_plan
      Rails.logger.info "⚠️ [PlansController#create] Found existing plan: ID=#{existing_plan.id}, name=#{existing_plan.plan_name}, plan_year=#{existing_plan.plan_year}"
    else
      Rails.logger.info "✅ [PlansController#create] No existing plan found"
    end
    
    existing_plan
  end

  # 選択された作物を取得
  def find_selected_crops
    Rails.logger.info "🔍 [PlansController#create] Finding selected crops with IDs: #{crop_ids.inspect}"
    
    if crop_ids.empty?
      Rails.logger.warn "⚠️ [PlansController#create] No crop IDs provided"
      return []
    end
    
    # ユーザー所有かつ非参照の作物のみ取得（Policy 経由）
    crops = CropPolicy.user_owned_non_reference_scope(current_user).where(id: crop_ids)
    Rails.logger.info "🌾 [PlansController#create] Found #{crops.count} crops for user #{current_user.id}"
    crops.each { |crop| Rails.logger.info "  - #{crop.name} (ID: #{crop.id})" }
    
    crops
  end

  # 最適化画面へのリダイレクト
  def redirect_to_optimizing(plan_id)
    redirect_with_log(optimizing_plan_path(plan_id), 'plans.messages.plan_created')
  end

  # 共通リダイレクト処理
  def redirect_with_log(path, message_key = nil, alert_key = nil)
    Rails.logger.info "🔄 [PlansController] Redirecting to: #{path}"
    options = {}
    options[:notice] = I18n.t(message_key) if message_key
    options[:alert] = I18n.t(alert_key) if alert_key
    redirect_to path, options
  end

end
