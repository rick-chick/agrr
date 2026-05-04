# frozen_string_literal: true

class Api::V1::PublicPlansController < Api::V1::BaseController
  # API用の無料作付け計画保存アクション
  def save_plan
    Rails.logger.info "🔍 [API PublicPlans#save_plan] Called"

    presenter = Presenters::Api::PublicPlan::PublicPlanSaveFromSessionApiPresenter.new(view: self)
    fdto = Domain::CultivationPlan::Dtos::PublicPlanSaveFailureDto

    plan_id = params[:plan_id]
    unless plan_id.present?
      Rails.logger.warn "❌ [API PublicPlans#save_plan] plan_id is missing"
      presenter.on_failure(fdto.new(kind: fdto::KIND_MISSING_PLAN_ID))
      return
    end

    cultivation_plan = CultivationPlan.find_by(id: plan_id)
    unless cultivation_plan
      Rails.logger.warn "❌ [API PublicPlans#save_plan] Plan not found: #{plan_id}"
      presenter.on_failure(fdto.new(kind: fdto::KIND_PLAN_NOT_FOUND))
      return
    end

    save_data = {
      plan_id: cultivation_plan.id,
      farm_id: cultivation_plan.farm_id,
      crop_ids: cultivation_plan.crops.pluck(:id),
      field_data: cultivation_plan.cultivation_plan_fields.map do |field|
        {
          name: field.name,
          area: field.area,
          coordinates: [ 35.0, 139.0 ]
        }
      end
    }

    Domain::CultivationPlan::Interactors::PublicPlanSaveFromSessionInteractor.new(
      output_port: presenter,
      public_plan_save_gateway: CompositionRoot.public_plan_save_gateway,
      logger: CompositionRoot.logger,
      translator: CompositionRoot.translator
    ).call(user: current_user, session_data: save_data)
  end
end
