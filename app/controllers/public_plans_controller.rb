# frozen_string_literal: true

class PublicPlansController < CultivationPlanHtmlBaseController

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
    presenter = Adapters::PublicPlan::Presenters::ReferenceFarmsHtmlPresenter.new(view: self)
    Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(output_port: presenter, gateway: CompositionRoot.farm_gateway, logger: CompositionRoot.logger).call(region)

    Rails.logger.debug "🌍 [PublicPlans#new] locale=#{I18n.locale}, region=#{region}, farms=#{@farms.count}"
  end

  # Step 2: 農場サイズ選択
  def select_farm_size
    failure = Adapters::PublicPlan::Presenters::PublicPlanWizardAlertRedirectHtmlPresenter.new(view: self, path_helper: :public_plans_path)
    farm = Domain::PublicPlan::Interactors::PublicPlanWizardLoadFarmInteractor.new(
      public_plan_gateway: CompositionRoot.public_plan_gateway,
      failure_presenter: failure
    ).call(farm_id: params[:farm_id].to_i, alert_i18n_key: "public_plans.errors.select_region")
    return if performed?

    @farm = farm
    @farm_sizes = farm_sizes_with_i18n

    session[:public_plan] = { farm_id: farm.id }
  end

  # Step 3: 作物選択
  def select_crop
    crop_step_presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardCropStepHtmlPresenter.new(view: self)
    Domain::PublicPlan::Interactors::PublicPlanWizardPrepareCropStepInteractor.new(
      public_plan_gateway: CompositionRoot.public_plan_gateway,
      output_port: crop_step_presenter
    ).call(farm_id: session_data[:farm_id], farm_size_id: params[:farm_size_id])
    return if performed?

    @farm_size = farm_sizes_with_i18n.find { |fs| fs[:id] == params[:farm_size_id] }

    presenter = Adapters::PublicPlan::Presenters::ReferenceCropsHtmlPresenter.new(view: self)
    Domain::Crop::Interactors::CropListReferenceEntitiesInteractor.new(output_port: presenter, gateway: CompositionRoot.crop_gateway, logger: CompositionRoot.logger).call(region: @farm.region)
    session[:public_plan] = session_data.merge(
      total_area: @farm_size[:area_sqm],
      farm_size_id: @farm_size[:id]
    )
  end

  # Step 4: 作付け計画作成（計算開始）
  def create
    unless session_data[:farm_id] && session_data[:total_area]
      redirect_to public_plans_path, alert: I18n.t("public_plans.errors.restart") and return
    end

    input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInput.new(
      farm_id: session_data[:farm_id],
      farm_size_id: session_data[:farm_size_id],
      crop_ids: crop_ids,
      session_id: session.id.to_s,
      user: current_user,
      redirect_path: job_completion_redirect_path
    )

    presenter = Adapters::PublicPlan::Presenters::PublicPlanCreateHtmlPresenter.new(
      view: self,
      public_plan_gateway: CompositionRoot.public_plan_gateway,
      crop_gateway: CompositionRoot.crop_gateway,
      logger: CompositionRoot.logger
    )

    Domain::PublicPlan::Interactors::PublicPlanCreateInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.public_plan_gateway,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      logger: CompositionRoot.logger,
      clock: Time.zone,
      optimization_job_chain_gateway: CompositionRoot.public_plan_optimization_job_chain_gateway
    ).call(input_dto)
  end

  # HTML Presenter / NoCropsFailureInteractor から: インスタンス変数の代入とテンプレ描画のみ
  def public_plan_render_select_crop_no_crops_failure!(farm:, farm_size:, crops:)
    @farm = farm
    @farm_size = farm_size
    @crops = crops
    flash.now[:alert] = I18n.t("public_plans.errors.select_crop")
    render :select_crop, status: :unprocessable_entity
  end

  # Step 5: 最適化進捗画面（広告表示）
  def optimizing
    plan_id = normalize_public_plan_wizard_plan_id
    presenter = Adapters::PublicPlan::Presenters::PublicPlanOptimizingHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
      output_port: presenter,
      plan_id: plan_id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger
    ).call
    return if performed?
  end

  # Step 6: 結果表示
  def results
    presenter = Adapters::PublicPlan::Presenters::PublicPlanResultsHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PublicPlanResultsInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.cultivation_plan_gateway,
      clock: Time.zone
    ).call(plan_id: normalize_public_plan_wizard_plan_id)
    return if performed?
  end

  # 保存ボタンクリック時の処理（HTML用）およびAPI用
  def save_plan
    # API リクエストの場合（JSONレスポンス）
    if request.format.json?
      handle_api_save_plan
      return
    end

    plan_id = normalize_public_plan_wizard_plan_id
    presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardSaveDispatchHtmlPresenter.new(
      view: self,
      clear_stashed_save_data_on_success: false
    )
    Domain::CultivationPlan::Interactors::PublicPlanWizardSaveDispatchInteractor.new(
      output_port: presenter,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      public_plan_save_gateway: CompositionRoot.public_plan_save_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(
      plan_id: plan_id,
      farm_id: session_data[:farm_id],
      crop_ids: session_data[:crop_ids],
      user: current_user
    )
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
    presenter = Adapters::PublicPlan::Presenters::PublicPlanSaveFromSessionHtmlPresenter.new(
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

  # API用の保存処理
  def handle_api_save_plan
    Rails.logger.info "🔍 [handle_api_save_plan] Called"

    unless current_user
      Rails.logger.warn "❌ [handle_api_save_plan] User not authenticated"
      render json: { success: false, error: "Authentication required" }, status: :unauthorized
      return
    end

    presenter = Adapters::PublicPlan::Presenters::PublicPlanSaveFromSessionApiApiPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PublicPlanSaveByPlanIdInteractor.new(
      output_port: presenter,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      public_plan_save_gateway: CompositionRoot.public_plan_save_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(plan_id: params[:plan_id], user: current_user)
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

  def normalize_public_plan_wizard_plan_id
    raw = params[:id] || params[:plan_id] || params[:planId] || session_data[:plan_id]
    return nil if raw.blank?

    i = Integer(raw, exception: false)
    return nil unless i&.positive?

    i
  end

  # 基底クラスで要求されるフックの実装

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

end
