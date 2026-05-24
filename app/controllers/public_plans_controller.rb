# frozen_string_literal: true

class PublicPlansController < CultivationPlanHtmlBaseController

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  layout "public"

  # 基底クラス属性
  self.plan_type = "public"
  self.session_key = :public_plan
  self.redirect_path_method = :public_plans_path

  # Step 1: 栽培地域（参照農場）選択（レガシー HTML。SPA は /public-plans/new）
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

  # Step 4: 作付け計画作成（レガシー HTML POST。SPA は API wizard#create）
  def create
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

  private

  def job_completion_redirect_path
    "#{spa_frontend_origin}/public-plans/results"
  end

  def spa_frontend_origin
    ENV.fetch("FRONTEND_URL", "http://localhost:4200").split(",").map(&:strip).reject(&:empty?).first
  end

  def channel_class
    OptimizationChannel
  end

end
