# frozen_string_literal: true

class PublicPlansController < ApplicationController
  include CultivationPlanManageable
  include JobExecution
  include WeatherDataManagement
  
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  layout 'public'
  
  # Concern設定
  self.plan_type = 'public'
  self.session_key = :public_plan
  self.redirect_path_method = :public_plans_path
  
  # 農場サイズの定数定義
  def self.farm_sizes
    [
      { id: 'home_garden', area_sqm: 30 },
      { id: 'community_garden', area_sqm: 50 },
      { id: 'rental_farm', area_sqm: 300 }
    ]
  end
  
  def farm_sizes_with_i18n
    self.class.farm_sizes.map do |size|
      size.merge(
        name: I18n.t("public_plans.farm_sizes.#{size[:id]}.name"),
        description: I18n.t("public_plans.farm_sizes.#{size[:id]}.description")
      )
    end
  end
  
  # Step 1: 栽培地域（参照農場）選択
  def new
    # URLのlocaleから地域を自動取得（/ja → jp, /us → us）
    # デフォルト: jp
    region = locale_to_region(I18n.locale)
    
    # 選択された地域の参照農場のみ取得
    @farms = Farm.reference.where(region: region).to_a
    
    Rails.logger.debug "🌍 [PublicPlans#new] locale=#{I18n.locale}, region=#{region}, farms=#{@farms.count}"
  end
  
  # Step 2: 農場サイズ選択
  def select_farm_size
    @farm = Farm.find(params[:farm_id])
    @farm_sizes = farm_sizes_with_i18n
    
    session[:public_plan] = { farm_id: @farm.id }
    Rails.logger.debug "✅ [PublicPlans] セッション保存: #{session[:public_plan].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.select_region')
  end
  
  # Step 3: 作物選択
  def select_crop
    Rails.logger.debug "🔍 [PublicPlans] セッション確認: #{session[:public_plan].inspect}"
    Rails.logger.debug "🔍 [PublicPlans] session_data: #{session_data.inspect}"
    
    unless session_data[:farm_id]
      Rails.logger.warn "⚠️  [PublicPlans] farm_id がセッションにありません"
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart') and return
    end
    
    @farm = Farm.find(session_data[:farm_id])
    @farm_size = farm_sizes_with_i18n.find { |fs| fs[:id] == params[:farm_size_id] }
    
    unless @farm_size
      redirect_to select_farm_size_public_plans_path(farm_id: @farm.id), 
                  alert: I18n.t('public_plans.errors.select_farm_size') and return
    end
    
    # 選択された農場の地域の作物のみ取得
    @crops = Crop.reference.where(region: @farm.region).order(:name)
    session[:public_plan] = session_data.merge(
      total_area: @farm_size[:area_sqm],
      farm_size_id: @farm_size[:id]
    )
    Rails.logger.debug "✅ [PublicPlans] セッション更新: #{session[:public_plan].inspect}"
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart')
  end
  
  # Step 4: 作付け計画作成（計算開始）
  def create
    unless session_data[:farm_id] && session_data[:total_area]
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.restart') and return
    end
    
    farm = Farm.find(session_data[:farm_id])
    total_area = session_data[:total_area]
    
    Rails.logger.debug "🔍 [PublicPlansController] crop_ids: #{crop_ids.inspect}"
    crops = Crop.where(id: crop_ids)
    Rails.logger.debug "🔍 [PublicPlansController] found crops: #{crops.count}"
    crops.each { |crop| Rails.logger.debug "  - #{crop.name} (ID: #{crop.id})" }
    
    if crops.empty?
      redirect_to select_crop_public_plans_path, alert: I18n.t('public_plans.errors.select_crop') and return
    end
    
    # セッションIDを取得
    session_id = session.id.to_s
    Rails.logger.info "🔑 [PublicPlansController#create] Using session_id: #{session_id}"
    
    # 計画作成パラメータを構築
    creator_params = {
      farm: farm,
      total_area: session_data[:total_area],
      crops: crops,
      user: current_user,
      session_id: session_id,
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }
    
    # Service で計画作成（最適化はしない）
    result = CultivationPlanCreator.new(**creator_params).call
    cultivation_plan = result.cultivation_plan

    # セッションに計画IDを保存
    session[:public_plan] = session_data.merge(plan_id: cultivation_plan.id)
    Rails.logger.info "💾 [PublicPlansController#create] Saved plan_id: #{cultivation_plan.id} to session"

    # ジョブチェーンを実行（データ取得 → 予測 → 最適化）
    job_instances = create_job_instances_for_public_plans(cultivation_plan.id, OptimizationChannel)
    execute_job_chain_async(job_instances)
    
    # 天気予測実行のためにoptimizing画面にリダイレクト
    redirect_to optimizing_public_plans_path
  end
  
  # Step 5: 最適化進捗画面（広告表示）
  def optimizing
    handle_optimizing(force_weather_only: false)
  end
  
  # Step 6: 結果表示
  def results
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    # まだ完了していない場合は進捗画面へ
    redirect_to optimizing_public_plans_path unless @cultivation_plan.status_completed?
  end
  
  # 保存ボタンクリック時の処理
  def save_plan
    Rails.logger.info "🔍 [save_plan] Called - logged_in?: #{logged_in?}"
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    if logged_in?
      Rails.logger.info "✅ [save_plan] User is logged in, saving to account"
      # ログイン済みの場合、直接保存処理を実行
      save_plan_to_user_account
    else
      Rails.logger.info "ℹ️ [save_plan] User is not logged in, redirecting to login"
      # 未ログインの場合、セッションに保存してログイン画面へ
      save_plan_data_to_session
      redirect_to auth_login_path, notice: I18n.t('public_plans.save.login_required')
    end
  end
  
  # ログイン後の保存処理
  def process_saved_plan
    return unless session[:public_plan_save_data]
    
    begin
      result = PlanSaveService.new(
        user: current_user,
        session_data: session[:public_plan_save_data]
      ).call
      
      if result.success
        session.delete(:public_plan_save_data)
        redirect_to plans_path, notice: I18n.t('public_plans.save.success')
      else
        redirect_to results_public_plans_path, alert: result.error_message || I18n.t('public_plans.save.error')
      end
    rescue => e
      Rails.logger.error "❌ [process_saved_plan] Error: #{e.message}"
      redirect_to results_public_plans_path, alert: I18n.t('public_plans.save.error')
    end
  end
  
  private
  
  # localeから地域コードに変換（/ja → jp, /us → us, /in → in）
  def locale_to_region(locale)
    case locale.to_s
    when 'ja'
      'jp'
    when 'us'
      'us'
    when 'in'
      'in'
    else
      'jp'  # デフォルトは日本
    end
  end
  
  # Concernで実装すべきメソッド
  
  def find_cultivation_plan_scope
    CultivationPlan
  end
  
  # ジョブインスタンスを作成（public plans用）
  def create_job_instances_for_public_plans(cultivation_plan_id, channel_class)
    Rails.logger.info "🔧 [PublicPlansController] Creating job instances for plan: #{cultivation_plan_id}"
    
    # 計画を取得
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    farm = cultivation_plan.farm
    
    # 天気データ取得のパラメータを計算
    weather_params = calculate_weather_data_params(farm.weather_location)
    predict_days = calculate_predict_days(weather_params[:end_date])
    
    Rails.logger.info "🌤️ [PublicPlansController] Weather params: #{weather_params}, predict_days: #{predict_days}"
    
    # ジョブインスタンスを作成
    job_instances = []
    
    # 1. 天気データ取得ジョブ
    fetch_job = FetchWeatherDataJob.new
    fetch_job.farm_id = farm.id
    fetch_job.latitude = farm.latitude
    fetch_job.longitude = farm.longitude
    fetch_job.start_date = weather_params[:start_date]
    fetch_job.end_date = weather_params[:end_date]
    fetch_job.cultivation_plan_id = cultivation_plan_id
    fetch_job.channel_class = channel_class
    job_instances << fetch_job
    
    # 2. 天気予測ジョブ
    prediction_job = WeatherPredictionJob.new
    prediction_job.cultivation_plan_id = cultivation_plan_id
    prediction_job.channel_class = channel_class
    prediction_job.predict_days = predict_days
    job_instances << prediction_job
    
    # 3. 最適化ジョブ
    optimization_job = OptimizationJob.new
    optimization_job.cultivation_plan_id = cultivation_plan_id
    optimization_job.channel_class = channel_class
    job_instances << optimization_job
    
    Rails.logger.info "✅ [PublicPlansController] Created #{job_instances.length} job instances"
    job_instances
  end

  # テスト用のオーバーライド: URLパラメータでplan_idを受け取る
  def find_cultivation_plan
    # テスト用: URLパラメータでplan_idを受け取る（開発・テスト環境のみ）
    plan_id = if Rails.env.test? && params[:plan_id].present?
      params[:plan_id]
    else
      params[:id] || session_data[:plan_id]
    end
    
    unless plan_id
      redirect_to public_plans_path, alert: I18n.t('public_plans.errors.not_found')
      return nil
    end
    
    find_cultivation_plan_scope
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_plans_path, alert: I18n.t('public_plans.errors.not_found')
    nil
  end
  
  def select_crop_redirect_path
    :select_crop_public_plans_path
  end
  
  def optimizing_redirect_path
    :optimizing_public_plans_path
  end
  
  def completion_redirect_path
    :results_public_plans_path
  end
  
  def channel_class
    OptimizationChannel
  end
  
  # JobExecutionで使用する遷移先パス
  def job_completion_redirect_path
    results_public_plans_path
  end
  
  # セッションに保存データを保存
  def save_plan_data_to_session
    # 圃場データを取得
    field_data = @cultivation_plan.cultivation_plan_fields.map do |field|
      {
        name: field.name,
        area: field.area,
        coordinates: [35.0, 139.0] # デフォルト座標（実際の座標があれば使用）
      }
    end
    
    session[:public_plan_save_data] = {
      plan_id: @cultivation_plan.id,
      farm_id: session_data[:farm_id],
      crop_ids: session_data[:crop_ids],
      field_data: field_data
    }
    Rails.logger.info "💾 [save_plan_data_to_session] Saved to session: #{session[:public_plan_save_data]}"
  end
  
  # ログイン済みユーザーのアカウントに保存
  def save_plan_to_user_account
    Rails.logger.info "💾 [save_plan_to_user_account] Starting save process for user: #{current_user.id}"
    
    begin
      # 重複チェック: 既に同じ計画が保存されているか
      existing_plan = current_user.cultivation_plans.find_by(
        plan_type: 'private',
        total_area: @cultivation_plan.total_area,
        planning_start_date: @cultivation_plan.planning_start_date,
        planning_end_date: @cultivation_plan.planning_end_date
      )
      
      if existing_plan
        Rails.logger.warn "⚠️ [save_plan_to_user_account] Duplicate plan detected: #{existing_plan.id}"
        redirect_to results_public_plans_path, alert: "この計画は既に保存されています。" and return
      end
      
      # セッションデータを構築
      # 圃場データを取得
      field_data = @cultivation_plan.cultivation_plan_fields.map do |field|
        {
          name: field.name,
          area: field.area,
          coordinates: [35.0, 139.0] # デフォルト座標（実際の座標があれば使用）
        }
      end
      
      save_data = {
        plan_id: @cultivation_plan.id,
        farm_id: session_data[:farm_id],
        crop_ids: session_data[:crop_ids],
        field_data: field_data
      }
      
      # PlanSaveServiceを呼び出し
      result = PlanSaveService.new(
        user: current_user,
        session_data: save_data
      ).call
      
      if result.success
        Rails.logger.info "✅ [save_plan_to_user_account] Plan saved successfully"
        redirect_to plans_path, notice: I18n.t('public_plans.save.success')
      else
        Rails.logger.error "❌ [save_plan_to_user_account] Save failed: #{result.error_message}"
        redirect_to results_public_plans_path, alert: result.error_message || I18n.t('public_plans.save.error')
      end
    rescue => e
      Rails.logger.error "❌ [save_plan_to_user_account] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to results_public_plans_path, alert: I18n.t('public_plans.save.error')
    end
  end
end

