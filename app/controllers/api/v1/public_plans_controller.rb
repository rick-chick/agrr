# frozen_string_literal: true

class Api::V1::PublicPlansController < Api::V1::BaseController
  # API用の無料作付け計画保存アクション
  def save_plan
    Rails.logger.info "🔍 [API PublicPlans#save_plan] Called"

    presenter = Adapters::PublicPlan::Presenters::PublicPlanSaveFromSessionApiApiPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.new(
      output_port: presenter,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      save_from_session_runner: CompositionRoot.public_plan_save_from_session_runner,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(plan_id: params[:plan_id], user: current_user)
  end
end
