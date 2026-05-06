# frozen_string_literal: true

class PlansController < ApplicationController
  include CultivationPlanManageable
  include WeatherDataManagement

  before_action :authenticate_user!
  before_action :set_plan, only: [ :optimize, :copy ]
  layout "application"

  # Concern設定
  self.plan_type = "private"
  self.session_key = :plan_data
  self.redirect_path_method = :plans_path

  # 計画一覧（農場別）
  def index
    presenter = Presenters::Html::Plans::PrivatePlanIndexHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
    return if performed?

    Rails.logger.debug "📅 [Plans#index] User: #{current_user.id}, Plan rows: #{@private_plan_index.plan_rows.size}"
  end

  # Step 1: 農場選択
  def new
    presenter = Presenters::Html::Plans::PrivatePlanNewHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PrivatePlanNewInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      farm_gateway: CompositionRoot.farm_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
    return if performed?

    Rails.logger.debug "🌍 [Plans#new] User: #{current_user.id}, Farms: #{@private_plan_new.farm_choices.size}"
  end

  # Step 2: 作物選択
  def select_crop
    farm_id = parse_positive_route_id(params[:farm_id])
    unless farm_id
      redirect_to new_plan_path, alert: I18n.t("plans.errors.select_farm") and return
    end

    load_private_plan_select_crop_context(farm_id)
    return if performed?

    # セッションに保存（plan_yearは使用しない - 年度という概念は削除されました）
    session[self.class.session_key] = {
      farm_id: @farm.id,
      plan_name: @plan_name,
      total_area: @total_area
    }

    Rails.logger.debug "✅ [Plans#select_crop] Session saved: #{session[:plan_data].inspect}"
  end

  # Step 3: 計画作成（最適化はしない）
  def create
    return unless validate_session_data

    farm = find_farm_from_session
    unless farm
      redirect_to new_plan_path, alert: I18n.t("plans.errors.restart") and return
    end
    crops = find_selected_crops

    if crops.empty?
      # Turbo対応: フォールバックせず同画面を422で再描画
      farm_id = parse_positive_route_id(session_data[:farm_id])
      unless farm_id
        redirect_to new_plan_path, alert: I18n.t("plans.errors.restart") and return
      end

      load_private_plan_select_crop_context(farm_id)
      return if performed?

      flash.now[:alert] = I18n.t("plans.errors.select_crop")
      return render :select_crop, status: :unprocessable_entity
    end

    # 既存の計画があるかチェック（通年計画: farm_id × user_idのみで検索）
    # @deprecated plan_yearの参照は後方互換性のため残していますが、新しい計画ではplan_yearはnilです。
    existing_plan = find_existing_plan(farm)
    if existing_plan
      Rails.logger.info "⚠️ [PlansController#create] Existing plan found: #{existing_plan.id}"
      if existing_plan.plan_year.present?
        redirect_to plan_path(existing_plan), alert: I18n.t("plans.errors.plan_already_exists", year: existing_plan.plan_year)
      else
        redirect_to plan_path(existing_plan), alert: I18n.t("plans.errors.plan_already_exists_annual")
      end
      return
    end

    result = create_cultivation_plan_with_jobs(farm, crops)
    redirect_to_optimizing(result.cultivation_plan.id)
  end

  # 計画の最適化を実行
  def optimize
    # 既に最適化中の場合はスキップ（完了は許可）
    if @plan.status_optimizing?
      redirect_to plan_path(@plan), alert: I18n.t("plans.errors.already_optimized") and return
    end

    # 最適化は計画作成時に既に実行されているため、進捗画面にリダイレクト
    redirect_to optimizing_plan_path(@plan.id), notice: I18n.t("plans.messages.optimization_started")
  end

  # Step 4: 最適化進捗画面
  def optimizing
    plan_id = parse_positive_route_id(params[:id])
    unless plan_id
      redirect_to plans_path, alert: I18n.t("plans.errors.not_found") and return
    end

    Rails.logger.info "🎯 [PlansController#optimizing] Starting optimizing view for plan: #{plan_id}"
    load_private_plan_optimizing(plan_id)
    return if performed?

    dto = @private_plan_optimizing
    if dto.completed?
      redirect_to plan_path(dto.id)
      return
    end

    if dto.failed?
      redirect_to plan_path(dto.id), alert: I18n.t("plans.optimizing.error.title")
      return
    end
  end

  # Step 5: 計画詳細（結果表示）
  def show
    plan_id = parse_positive_route_id(params[:id])
    unless plan_id
      redirect_to plans_path, alert: I18n.t("plans.errors.not_found") and return
    end

    presenter = Presenters::Html::Plans::PrivatePlanShowHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      plan_id: plan_id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
    return if performed?

    if @private_plan_show.optimizing?
      redirect_to optimizing_plan_path(@private_plan_show.id) and return
    end

    Rails.logger.debug "📊 [Plans#show] User: #{current_user.id}, Plan: #{@private_plan_show.id}"
  end

  # @deprecated 年度という概念は削除されました。コピー機能は無効化されています。
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    source_plan = @plan

    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、
    # コピー機能は無効化されました（通年計画と年度ベースの計画の両方）
    # 既存の年度ベースの計画は後方互換性のために保持されますが、
    # 新しい計画は通年計画として作成されるため、コピー機能は不要です
    redirect_to plans_path, alert: I18n.t("plans.errors.copy_not_available_for_annual_planning") and return
  end

  # 計画削除（Undo 対応は Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor へ委譲）
  def destroy
    presenter = Presenters::Html::Plans::CultivationPlanDestroyHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator,
      user_lookup: CompositionRoot.user_lookup
    ).call(params[:id])
  end

  private

  def load_private_plan_select_crop_context(farm_id)
    presenter = Presenters::Html::Plans::PrivatePlanSelectCropHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      farm_id: farm_id,
      field_gateway: CompositionRoot.field_gateway,
      crop_gateway: CompositionRoot.crop_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
  end

  def load_private_plan_optimizing(plan_id)
    presenter = Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      plan_id: plan_id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      user_lookup: CompositionRoot.user_lookup
    ).call
  end

  # ルートパラメータの正の整数 ID（計画 :id・作物選択 farm_id 等）。"abc" / 0 / 空白は nil
  def parse_positive_route_id(raw)
    return nil if raw.nil?

    s = raw.is_a?(Integer) ? raw.to_s : raw.to_s.strip
    return nil if s.empty?

    return nil unless s.match?(/\A[1-9]\d*\z/)

    s.to_i
  end

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

  # ジョブチェーン完了後のリダイレクト先（JobChainAsyncDispatcher に渡す）
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
    result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor.new(**creator_params, gateway: CompositionRoot.cultivation_plan_gateway, logger: CompositionRoot.logger).call

    # エラーハンドリング: 計画作成に失敗した場合
    unless result.success? && result.cultivation_plan
      Rails.logger.error "❌ [PlansController#create] CultivationPlan creation failed: #{result.errors.join(', ')}"
      raise ActiveRecord::RecordInvalid.new(result.cultivation_plan || CultivationPlan.new)
    end

    Rails.logger.info "✅ [PlansController#create] CultivationPlan created: #{result.cultivation_plan.id}"
    session[self.class.session_key] = { plan_id: result.cultivation_plan.id }

    # ジョブチェーンを非同期実行
    job_instances = create_job_instances_for_plans(result.cultivation_plan.id, PlansOptimizationChannel)
    CompositionRoot.job_chain_async_dispatcher.enqueue(
      job_instances,
      redirect_path: job_completion_redirect_path,
      caller_label: self.class.name
    )

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
      redirect_to new_plan_path, alert: I18n.t("plans.errors.restart")
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
      return nil
    end

    farm = current_user.farms.find_by(id: farm_id)
    unless farm
      Rails.logger.warn "⚠️ [PlansController#create] Farm not found for user"
      return nil
    end

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

    presenter = Presenters::Html::Plans::SelectedCropsPresenter.new(view: self)
    Domain::Crop::Interactors::CropListUserOwnedNonReferenceByIdsInteractor.new(output_port: presenter,
      user_id: current_user.id, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger, user_lookup: CompositionRoot.user_lookup).call(crop_ids)

    crops = @selected_crops || []
    Rails.logger.info "🌾 [PlansController#create] Found #{crops.count} crops for user #{current_user.id}"
    crops.each { |crop| Rails.logger.info "  - #{crop.name} (ID: #{crop.id})" }

    crops
  end

  # 最適化画面へのリダイレクト
  def redirect_to_optimizing(plan_id)
    redirect_with_log(optimizing_plan_path(plan_id), "plans.messages.plan_created")
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
