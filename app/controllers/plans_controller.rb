# frozen_string_literal: true

class PlansController < ApplicationController
  include CultivationPlanManageable
  include JobExecution
  include WeatherDataManagement
  
  before_action :authenticate_user!
  layout 'application'
  
  # Concern設定
  self.plan_type = 'private'
  self.session_key = :plan_data
  self.redirect_path_method = :plans_path
  
  # 定数
  AVAILABLE_YEARS_RANGE = 1 # 現在年から前後何年まで表示するか
  PLAN_TYPE_PRIVATE = 'private'
  SESSION_ID_KEY = :plan_data
  
  # 計画一覧（年度別）
  def index
    @current_year = Date.current.year
    @available_years = available_years_range
    
    # ユーザーの全計画を取得（年度別にグループ化）
    @plans_by_year = CultivationPlan
      .plan_type_private
      .by_user(current_user)
      .includes(:farm, field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .recent
      .group_by(&:plan_year)
    
    Rails.logger.debug "📅 [Plans#index] User: #{current_user.id}, Plans: #{@plans_by_year.keys.inspect}"
  end
  
  # Step 1: 年度・農場選択
  def new
    @current_year = Date.current.year
    @available_years = available_years_range
    
    # ユーザーの農場を取得
    @farms = current_user.farms.user_owned.to_a
    
    # デフォルト計画名
    @default_plan_name = I18n.t('plans.default_plan_name')
    
    Rails.logger.debug "🌍 [Plans#new] User: #{current_user.id}, Farms: #{@farms.count}"
  end
  
  # Step 2: 作物選択
  def select_crop
    unless params[:plan_year].present? && params[:farm_id].present?
      redirect_to new_plan_path, alert: I18n.t('plans.errors.select_year_and_farm') and return
    end
    
    @plan_year = params[:plan_year].to_i
    @farm = current_user.farms.find(params[:farm_id])
    # 計画名は農場名を自動設定
    @plan_name = @farm.name
    
    # ユーザーの作物のみ取得
    @crops = current_user.crops.where(is_reference: false).order(:name)
    
    # 農場の圃場を取得
    @fields = @farm.fields.order(:name)
    
    # 総面積を計算
    @total_area = @fields.sum(:area)
    
    # セッションに保存
    session[:plan_data] = {
      plan_year: @plan_year,
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
    return unless validate_crops_selection(crops)
    
    # 既存の計画があるかチェック
    existing_plan = find_existing_plan(farm)
    if existing_plan
      Rails.logger.info "⚠️ [PlansController#create] Existing plan found: #{existing_plan.id}"
      redirect_to plan_path(existing_plan), alert: I18n.t('plans.errors.plan_already_exists', year: existing_plan.plan_year)
      return
    end
    
    result = create_cultivation_plan_with_jobs(farm, crops)
    redirect_to_optimizing(result.cultivation_plan.id)
  rescue ActiveRecord::RecordNotFound
    redirect_to new_plan_path, alert: I18n.t('plans.errors.restart')
  end
  
  # 計画の最適化を実行
  def optimize
    plan = current_user.cultivation_plans.plan_type_private.find(params[:id])
    
    # 既に最適化中の場合はスキップ（完了は許可）
    if plan.status_optimizing?
      redirect_to plan_path(plan), alert: I18n.t('plans.errors.already_optimized') and return
    end
    
    # 最適化は計画作成時に既に実行されているため、進捗画面にリダイレクト
    redirect_to optimizing_plan_path(plan.id), notice: I18n.t('plans.messages.optimization_started')
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
  
  # Step 4: 最適化進捗画面
  def optimizing
    Rails.logger.info "🎯 [PlansController#optimizing] Starting optimizing view for plan: #{params[:id]}"
    handle_optimizing(force_weather_only: true)
  end
  
  # Step 5: 計画詳細（結果表示）
  def show
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # 最適化中の場合のみ進捗画面へ
    redirect_to optimizing_plan_path(@cultivation_plan.id) if @cultivation_plan.status_optimizing?
  end
  
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    source_plan = current_user.cultivation_plans.plan_type_private.find(params[:id])
    
    # 新しい年度を決定（現在の計画年度 + 1）
    new_year = source_plan.plan_year + 1
    
    # 既に同じ年度の計画がある場合はエラー
    if current_user.cultivation_plans.plan_type_private.exists?(plan_year: new_year, plan_name: source_plan.plan_name)
      redirect_to plans_path, alert: I18n.t('plans.errors.plan_already_exists', year: new_year) and return
    end
    
    # PlanCopierサービスで計画をコピー
    session_id = session.id.to_s
    result = PlanCopier.new(
      source_plan: source_plan,
      new_year: new_year,
      user: current_user,
      session_id: session_id
    ).call
    
    if result.success?
      redirect_to plan_path(result.new_plan), notice: I18n.t('plans.messages.plan_copied', year: new_year)
    else
      redirect_to plans_path, alert: I18n.t('plans.errors.copy_failed', errors: result.errors.join(', '))
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to plans_path, alert: I18n.t('plans.errors.not_found')
  end
  
  # 計画削除
  def destroy
    plan = current_user.cultivation_plans.plan_type_private.find(params[:id])

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
  
  def find_cultivation_plan_scope
    CultivationPlan
      .plan_type_private
      .by_user(current_user)
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
    
    [
      # データ取得
      weather_job,
      # 天気予測
      prediction_job,
      # 最適化
      optimization_job
    ]
  end

  # 年度範囲を計算するヘルパーメソッド
  def available_years_range
    current_year = Date.current.year
    ((current_year - AVAILABLE_YEARS_RANGE)..(current_year + AVAILABLE_YEARS_RANGE)).to_a
  end
  # 以降のセクションで詳細版の実装が存在するため、
  # 同等の機能を持つ重複メソッドは削除（振る舞いは不変）

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
    session[SESSION_ID_KEY] = { plan_id: result.cultivation_plan.id }
    
    # ジョブチェーンを非同期実行
    job_instances = create_job_instances_for_plans(result.cultivation_plan.id, PlansOptimizationChannel)
    execute_job_chain_async(job_instances)
    
    result
  end

  # 作成者パラメータを構築
  def build_creator_params(farm, crops)
    # セッションが欠落しているケースに備えて安全なデフォルトを用意
    plan_year = session_data[:plan_year].presence || Date.current.year
    plan_name = session_data[:plan_name].presence || farm.name
    planning_dates = CultivationPlan.calculate_planning_dates(plan_year)
    session_id = session.id.to_s
    
    Rails.logger.info "🔑 [PlansController#create] Using session_id: #{session_id}"
    Rails.logger.info "👤 [PlansController#create] Current user: #{current_user&.name} (#{current_user&.id})"
    Rails.logger.info "🏡 [PlansController#create] Farm: #{farm.name} (#{farm.id})"
    Rails.logger.info "🌾 [PlansController#create] Crops: #{crops.count} crops"
    Rails.logger.info "📊 [PlansController#create] Session data: #{session_data.inspect}"
    
    {
      farm: farm,
      total_area: session_data[:total_area].presence || farm.fields.sum(:area),
      crops: crops,
      user: current_user,
      session_id: session_id,
      plan_type: PLAN_TYPE_PRIVATE,
      plan_year: plan_year,
      plan_name: plan_name,
      planning_start_date: planning_dates[:start_date],
      planning_end_date: planning_dates[:end_date]
    }
  end

  # セッションデータの検証
  def validate_session_data
    Rails.logger.info "🔍 [PlansController#create] Validating session data (minimal): #{session_data.inspect}"
    required_present = session_data[:farm_id].present? && session_data[:plan_year].present?
    unless required_present
      Rails.logger.warn "⚠️ [PlansController#create] Missing minimal session data"
      redirect_to new_plan_path, alert: I18n.t('plans.errors.restart')
      return false
    end
    Rails.logger.info "✅ [PlansController#create] Minimal session data validation passed"
    true
  end

  # 作物選択の検証
  def validate_crops_selection(crops)
    Rails.logger.info "🔍 [PlansController#create] Validating crops selection: #{crops.count} crops"
    if crops.empty?
      Rails.logger.warn "⚠️ [PlansController#create] No crops selected"
      redirect_to select_crop_plans_path, alert: I18n.t('plans.errors.select_crop')
      return false
    end
    Rails.logger.info "✅ [PlansController#create] Crops selection validation passed"
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

  # 既存の計画を検索
  def find_existing_plan(farm)
    plan_year = session_data[:plan_year]
    Rails.logger.info "🔍 [PlansController#create] Checking for existing plan: farm_id=#{farm.id}, plan_year=#{plan_year}"
    
    existing_plan = current_user.cultivation_plans
      .where(farm: farm, plan_year: plan_year, plan_type: PLAN_TYPE_PRIVATE)
      .first
    
    if existing_plan
      Rails.logger.info "⚠️ [PlansController#create] Found existing plan: ID=#{existing_plan.id}, name=#{existing_plan.plan_name}"
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
    
    # ユーザーの作物のみ取得
    crops = current_user.crops.where(id: crop_ids, is_reference: false)
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
