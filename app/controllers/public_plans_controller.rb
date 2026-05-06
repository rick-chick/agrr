# frozen_string_literal: true

class PublicPlansController < CultivationPlanHtmlBaseController
  include WeatherDataManagement

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  layout "public"

  # 基底クラス属性
  self.plan_type = "public"
  self.session_key = :public_plan
  self.redirect_path_method = :public_plans_path

  # 農場サイズの定数定義
  def self.farm_sizes
    [
      { id: "home_garden", area_sqm: 30 },
      { id: "community_garden", area_sqm: 50 },
      { id: "rental_farm", area_sqm: 300 }
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

    # 選択された地域の参照農場のみ取得（Policy 経由）
    presenter = Presenters::Html::PublicPlans::ReferenceFarmsPresenter.new(view: self)
    Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)

    Rails.logger.debug "🌍 [PublicPlans#new] locale=#{I18n.locale}, region=#{region}, farms=#{@farms.count}"
  end

  # Step 2: 農場サイズ選択
  def select_farm_size
    @farm = Farm.find_by(id: params[:farm_id])
    unless @farm
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.select_region")
      return
    end

    @farm_sizes = farm_sizes_with_i18n

    session[:public_plan] = { farm_id: @farm.id }
    Rails.logger.debug "✅ [PublicPlans] セッション保存: #{session[:public_plan].inspect}"
  end

  # Step 3: 作物選択
  def select_crop
    Rails.logger.debug "🔍 [PublicPlans] セッション確認: #{session[:public_plan].inspect}"
    Rails.logger.debug "🔍 [PublicPlans] session_data: #{session_data.inspect}"

    unless session_data[:farm_id]
      Rails.logger.warn "⚠️  [PublicPlans] farm_id がセッションにありません"
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.restart") and return
    end

    @farm = Farm.find_by(id: session_data[:farm_id])
    unless @farm
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.restart") and return
    end

    @farm_size = farm_sizes_with_i18n.find { |fs| fs[:id] == params[:farm_size_id] }

    unless @farm_size
      redirect_to select_farm_size_public_plans_path(farm_id: @farm.id),
                  alert: I18n.t("public_plans.errors.select_farm_size") and return
    end

    presenter = Presenters::Html::PublicPlans::ReferenceCropsPresenter.new(view: self)
    Domain::Crop::Interactors::CropListReferenceEntitiesInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(region: @farm.region)
    session[:public_plan] = session_data.merge(
      total_area: @farm_size[:area_sqm],
      farm_size_id: @farm_size[:id]
    )
    Rails.logger.debug "✅ [PublicPlans] セッション更新: #{session[:public_plan].inspect}"
  end

  # Step 4: 作付け計画作成（計算開始）
  def create
    unless session_data[:farm_id] && session_data[:total_area]
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.restart") and return
    end

    farm = Farm.find_by(id: session_data[:farm_id])
    unless farm
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.restart") and return
    end

    Rails.logger.debug "🔍 [PublicPlansController] crop_ids: #{crop_ids.inspect}"
    crops = Crop.where(id: crop_ids)
    Rails.logger.debug "🔍 [PublicPlansController] found crops: #{crops.count}"
    crops.each { |crop| Rails.logger.debug "  - #{crop.name} (ID: #{crop.id})" }

    if crops.empty?
      # Turbo対応: フォールバックせず同画面を422で再描画
      @farm = farm
      @farm_size = farm_sizes_with_i18n.find { |fs| fs[:id] == session_data[:farm_size_id] }
      presenter = Presenters::Html::PublicPlans::ReferenceCropsPresenter.new(view: self)
      Domain::Crop::Interactors::CropListReferenceEntitiesInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(region: @farm.region)
      flash.now[:alert] = I18n.t("public_plans.errors.select_crop")
      return render :select_crop, status: :unprocessable_entity
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
      plan_type: "public",
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    }

    # Service で計画作成（最適化はしない）
    result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor.new(**creator_params, gateway: CompositionRoot.cultivation_plan_gateway, logger: CompositionRoot.logger).call
    cultivation_plan = result.cultivation_plan

    # セッションに計画IDを保存
    session[:public_plan] = session_data.merge(plan_id: cultivation_plan.id)
    Rails.logger.info "💾 [PublicPlansController#create] Saved plan_id: #{cultivation_plan.id} to session"

    # ジョブチェーンを実行（データ取得 → 予測 → 最適化）
    job_instances = create_job_instances_for_public_plans(cultivation_plan.id, OptimizationChannel)
    CompositionRoot.job_chain_async_dispatcher.enqueue(
      job_instances,
      redirect_path: job_completion_redirect_path,
      caller_label: self.class.name
    )

    # 天気予測実行のためにoptimizing画面にリダイレクト
    redirect_to optimizing_public_plans_path
  end

  # Step 5: 最適化進捗画面（広告表示）
  def optimizing
    plan_id = normalize_public_plan_wizard_plan_id
    presenter = Presenters::Html::PublicPlans::PublicPlanOptimizingHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
      output_port: presenter,
      plan_id: plan_id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger
    ).call
    return if performed?

    dto = @public_plan_optimizing
    if dto.completed?
      redirect_to public_plans_results_path
      return
    end

    if dto.failed?
      redirect_to public_plans_results_path, alert: I18n.t("public_plans.optimizing.error.title")
    end
  end

  # Step 6: 結果表示
  def results
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan

    # まだ完了していない場合は進捗画面へ
    redirect_to optimizing_public_plans_path unless @cultivation_plan.status_completed?

    # 作業予定が空の場合は警告トーストを表示するためのフラグを設定
    # 計画内の各圃場に対して作業予定が生成されているか確認
    # テンプレートがない作物がある場合、その圃場には作業予定が生成されない
    field_cultivations_with_schedules = @cultivation_plan.field_cultivations.select do |fc|
      @cultivation_plan.task_schedules.where(field_cultivation: fc).any? do |schedule|
        schedule.task_schedule_items.any?
      end
    end

    # 全ての圃場に作業予定が生成されていない場合は警告を表示
    @show_schedule_warning = field_cultivations_with_schedules.count < @cultivation_plan.field_cultivations.count
  end

  # 保存ボタンクリック時の処理（HTML用）およびAPI用
  def save_plan
    # API リクエストの場合（JSONレスポンス）
    if request.format.json?
      handle_api_save_plan
      return
    end

    # HTML リクエストの場合（既存の処理）
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
      redirect_to auth_login_path, notice: I18n.t("public_plans.save.login_required")
    end
  end

  # ログイン後の保存処理
  def process_saved_plan
    return unless session[:public_plan_save_data]

    run_public_plan_save_from_session_html(
      user: current_user,
      session_data: session[:public_plan_save_data],
      clear_stashed_save_data_on_success: true
    )
  end

  private

  def run_public_plan_save_from_session_html(user:, session_data:, clear_stashed_save_data_on_success:)
    presenter = Presenters::Html::PublicPlans::PublicPlanSaveFromSessionHtmlPresenter.new(
      view: self,
      clear_stashed_save_data_on_success: clear_stashed_save_data_on_success
    )
    Domain::CultivationPlan::Interactors::PublicPlanSaveFromSessionInteractor.new(
      output_port: presenter,
      public_plan_save_gateway: CompositionRoot.public_plan_save_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(user: user, session_data: session_data)
  end

  def public_plan_save_session_data_for(cultivation_plan, farm_id:, crop_ids:)
    field_data = cultivation_plan.cultivation_plan_fields.map do |field|
      {
        name: field.name,
        area: field.area,
        coordinates: [ 35.0, 139.0 ]
      }
    end

    {
      plan_id: cultivation_plan.id,
      farm_id: farm_id,
      crop_ids: crop_ids,
      field_data: field_data
    }
  end

  # API用の保存処理
  def handle_api_save_plan
    Rails.logger.info "🔍 [handle_api_save_plan] Called"

    unless current_user
      Rails.logger.warn "❌ [handle_api_save_plan] User not authenticated"
      render json: { success: false, error: "Authentication required" }, status: :unauthorized
      return
    end

    presenter = Presenters::Api::PublicPlan::PublicPlanSaveFromSessionApiPresenter.new(view: self)
    fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailureDto

    plan_id = params[:plan_id]
    unless plan_id.present?
      Rails.logger.warn "❌ [handle_api_save_plan] plan_id is missing"
      presenter.on_failure(fdto.new(kind: fdto::KIND_MISSING_PLAN_ID))
      return
    end

    cultivation_plan = CultivationPlan.find_by(id: plan_id)
    unless cultivation_plan
      Rails.logger.warn "❌ [handle_api_save_plan] Plan not found: #{plan_id}"
      presenter.on_failure(fdto.new(kind: fdto::KIND_PLAN_NOT_FOUND))
      return
    end

    save_data = public_plan_save_session_data_for(
      cultivation_plan,
      farm_id: cultivation_plan.farm_id,
      crop_ids: cultivation_plan.crops.pluck(:id)
    )

    Domain::CultivationPlan::Interactors::PublicPlanSaveFromSessionInteractor.new(
      output_port: presenter,
      public_plan_save_gateway: CompositionRoot.public_plan_save_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(user: current_user, session_data: save_data)
  end

  # localeから地域コードに変換（/ja → jp, /us → us, /in → in）
  def locale_to_region(locale)
    case locale.to_s
    when "ja"
      "jp"
    when "us"
      "us"
    when "in"
      "in"
    else
      "jp"  # デフォルトは日本
    end
  end

  # 基底クラスで要求されるフックの実装

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

    # 4. 作業予定生成ジョブ
    task_schedule_job = TaskScheduleGenerationJob.new
    task_schedule_job.cultivation_plan_id = cultivation_plan_id
    task_schedule_job.channel_class = channel_class
    job_instances << task_schedule_job

    Rails.logger.info "✅ [PublicPlansController] Created #{job_instances.length} job instances"
    job_instances
  end

  # テスト用のオーバーライド: URLパラメータでplan_idを受け取る
  def find_cultivation_plan
    plan_id = normalize_public_plan_wizard_plan_id
    result = Adapters::CultivationPlan::ManageablePublicPlanLookup.call(
      plan_id: plan_id,
      scope: find_cultivation_plan_scope,
      includes: [
        field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ],
        task_schedules: :task_schedule_items
      ]
    )

    case result[:kind]
    when :missing_plan_id, :not_found
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.not_found")
      nil
    else
      result[:plan]
    end
  end

  def normalize_public_plan_wizard_plan_id
    raw = params[:id] || params[:plan_id] || params[:planId] || session_data[:plan_id]
    return nil if raw.blank?

    i = Integer(raw, exception: false)
    return nil unless i&.positive?

    i
  end

  def select_crop_redirect_path
    :select_crop_public_plans_path
  end

  def optimizing_redirect_path
    :optimizing_public_plans_path
  end

  def completion_redirect_path
    :public_plans_results_path
  end

  def channel_class
    OptimizationChannel
  end

  # ジョブチェーン完了後のリダイレクト先（JobChainAsyncDispatcher に渡す）
  def job_completion_redirect_path
    public_plans_results_path
  end

  # セッションに保存データを保存
  def save_plan_data_to_session
    # 圃場データを取得
    field_data = @cultivation_plan.cultivation_plan_fields.map do |field|
      {
        name: field.name,
        area: field.area,
        coordinates: [ 35.0, 139.0 ] # デフォルト座標（実際の座標があれば使用）
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

    save_data = public_plan_save_session_data_for(
      @cultivation_plan,
      farm_id: session_data[:farm_id],
      crop_ids: session_data[:crop_ids]
    )

    run_public_plan_save_from_session_html(
      user: current_user,
      session_data: save_data,
      clear_stashed_save_data_on_success: false
    )
  end
end
