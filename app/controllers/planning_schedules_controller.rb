# frozen_string_literal: true

class PlanningSchedulesController < ApplicationController
  before_action :authenticate_user!
  layout "application"

  # デフォルト表示期間（来年から過去5年分）— テスト・定数参照用
  DEFAULT_YEARS_RANGE = Domain::CultivationPlan::PlanningScheduleConstants::DEFAULT_YEARS_RANGE

  # ほ場選択画面
  def fields_selection
    presenter = Adapters::CultivationPlan::Presenters::Html::PlanningScheduleFieldsSelectionHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PlanningScheduleFieldsSelectionInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      farm_gateway: CompositionRoot.farm_gateway,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      user_lookup: CompositionRoot.user_lookup,
      clock: Time.zone
    ).call(
      farm_id_param: params[:farm_id],
      field_ids_param: params[:field_ids]
    )
  end

  # 作付け計画表画面
  def schedule
    presenter = Adapters::CultivationPlan::Presenters::Html::PlanningScheduleMatrixHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::PlanningScheduleMatrixInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      farm_gateway: CompositionRoot.farm_gateway,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      user_lookup: CompositionRoot.user_lookup,
      translator: CompositionRoot.translator,
      logger: CompositionRoot.logger,
      clock: Time.zone
    ).call(
      farm_id_param: params[:farm_id],
      field_ids_param: params[:field_ids],
      session_farm_id: session[:planning_schedule_farm_id],
      session_field_ids: session[:planning_schedule_field_ids],
      year_param: params[:year],
      granularity_param: params[:granularity]
    )
    return if performed?

    render :schedule
  end
end
