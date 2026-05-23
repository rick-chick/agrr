# frozen_string_literal: true

class PublicPlansController < CultivationPlanHtmlBaseController

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  layout "public"

  # 基底クラス属性
  self.plan_type = "public"
  self.session_key = :public_plan
  self.redirect_path_method = :public_plans_path

  # Step 1: 栽培地域（参照農場）選択
  def new
    region = Domain::Shared::Mappers::LocaleToRegionMapper.call(I18n.locale)
    presenter = Adapters::PublicPlan::Presenters::ReferenceFarmsHtmlPresenter.new(view: self)
    Domain::Farm::Interactors::FarmListReferenceForRegionInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.farm_gateway,
      logger: CompositionRoot.logger
    ).call(region)
    return if performed?

    Rails.logger.debug "🌍 [PublicPlans#new] locale=#{I18n.locale}, region=#{region}, farms=#{@farms.count}"
  end

  # Step 2: 農場サイズ選択
  def select_farm_size
    presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardSelectFarmSizeHtmlPresenter.new(
      view: self,
      path_helper: :public_plans_path
    )
    Domain::PublicPlan::Interactors::PublicPlanWizardSelectFarmSizeInteractor.new(
      public_plan_gateway: CompositionRoot.public_plan_gateway,
      output_port: presenter
    ).call(
      farm_id: params[:farm_id].to_i,
      alert_i18n_key: "public_plans.errors.select_region"
    )
    return if performed?
  end

  # Step 3: 作物選択
  def select_crop
    presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardSelectCropHtmlPresenter.new(view: self)
    Domain::PublicPlan::Interactors::PublicPlanWizardSelectCropInteractor.new(
      public_plan_gateway: CompositionRoot.public_plan_gateway,
      crop_gateway: CompositionRoot.crop_gateway,
      output_port: presenter,
      logger: CompositionRoot.logger
    ).call(
      farm_id: session_data[:farm_id],
      farm_size_id: params[:farm_size_id]
    )
    return if performed?
  end

  # Step 4: 作付け計画作成（計算開始）
  def create
    session_presenter = Adapters::PublicPlan::Presenters::PublicPlanWizardCreateSessionHtmlPresenter.new(view: self)
    valid = Domain::PublicPlan::Interactors::PublicPlanWizardValidateCreateSessionInteractor.new(
      output_port: session_presenter
    ).call(session_data: session_data)
    return unless valid

    input_dto = Domain::PublicPlan::Dtos::PublicPlanCreateInput.new(
      farm_id: session_data[:farm_id],
      farm_size_id: session_data[:farm_size_id],
      crop_ids: crop_ids,
      session_id: session.id.to_s,
      user: current_user,
      redirect_path: job_completion_redirect_path
    )

    presenter = Adapters::PublicPlan::Presenters::PublicPlanCreateHtmlPresenter.new(view: self)

    Domain::PublicPlan::Interactors::PublicPlanCreateInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.public_plan_gateway,
      crop_gateway: CompositionRoot.crop_gateway,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      logger: CompositionRoot.logger,
      clock: Time.zone,
      optimization_job_chain_gateway: CompositionRoot.public_plan_optimization_job_chain_gateway
    ).call(input_dto)
  end

  # Step 5: 最適化進捗画面（広告表示）
  def optimizing
    plan_id = public_plan_wizard_plan_id
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
    ).call(plan_id: public_plan_wizard_plan_id)
    return if performed?
  end

  # 保存ボタンクリック時の処理（HTML用）およびAPI用
  def save_plan
    if request.format.json?
      handle_api_save_plan
      return
    end

    plan_id = public_plan_wizard_plan_id
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

  def public_plan_wizard_plan_id
    Domain::PublicPlan::Mappers::PublicPlanWizardPlanIdMapper.normalize(
      params[:id],
      params[:plan_id],
      params[:planId],
      session_data[:plan_id]
    )
  end

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

  def job_completion_redirect_path
    public_plans_results_path
  end

end
