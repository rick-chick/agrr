# frozen_string_literal: true

class Api::V1::PublicPlansController < Api::V1::BaseController
  # API用の無料作付け計画保存アクション
  def save_plan
    Rails.logger.info "🔍 [API PublicPlans#save_plan] Called"

    presenter = Adapters::PublicPlan::Presenters::PublicPlanSaveFromSessionApiApiPresenter.new(view: self)
    input = Domain::CultivationPlan::Dtos::PublicPlanSaveInput.new(
      plan_id: params[:plan_id],
      user_id: current_user.id
    )
    Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor.new(
      output_port: presenter,
      txn_gateway: CompositionRoot.cultivation_plan_gateway,
      read_gateway: CompositionRoot.public_plan_save_read_gateway,
      farm_gateway: CompositionRoot.farm_gateway,
      persistence_port: CompositionRoot.public_plan_save_persistence_port,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(input)
  end
end
