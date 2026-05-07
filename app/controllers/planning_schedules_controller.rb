# frozen_string_literal: true

class PlanningSchedulesController < ApplicationController
  before_action :authenticate_user!
  layout "application"

  # デフォルト表示期間（来年から過去5年分）— テスト・定数参照用
  DEFAULT_YEARS_RANGE = Domain::CultivationPlan::PlanningScheduleConstants::DEFAULT_YEARS_RANGE

  # ほ場選択画面
  def fields_selection
    presenter = Presenters::Html::Plans::PlanningScheduleFieldsSelectionHtmlPresenter.new(view: self)
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
    presenter = Presenters::Html::Plans::PlanningScheduleMatrixHtmlPresenter.new(view: self)
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

  # ヘルパーメソッドとして公開（ビューから呼び出し可能にするため）
  helper_method :get_crop_color_for_schedule

  # 作物名から一貫した色を取得（スケジュール表示用）
  def get_crop_color_for_schedule(crop_name)
    @crop_color_cache ||= {}

    return @crop_color_cache[crop_name] if @crop_color_cache[crop_name]

    color_palette = [
      { fill: "rgba(154, 230, 180, 0.8)", stroke: "#48bb78", text: "#1a202c" },
      { fill: "rgba(251, 211, 141, 0.8)", stroke: "#f6ad55", text: "#1a202c" },
      { fill: "rgba(144, 205, 244, 0.8)", stroke: "#4299e1", text: "#1a202c" },
      { fill: "rgba(198, 246, 213, 0.8)", stroke: "#2f855a", text: "#1a202c" },
      { fill: "rgba(254, 235, 200, 0.8)", stroke: "#dd6b20", text: "#1a202c" },
      { fill: "rgba(254, 178, 178, 0.8)", stroke: "#fc8181", text: "#1a202c" },
      { fill: "rgba(254, 243, 199, 0.8)", stroke: "#d69e2e", text: "#1a202c" },
      { fill: "rgba(233, 213, 255, 0.8)", stroke: "#a78bfa", text: "#1a202c" },
      { fill: "rgba(191, 219, 254, 0.8)", stroke: "#60a5fa", text: "#1a202c" },
      { fill: "rgba(252, 231, 243, 0.8)", stroke: "#f472b6", text: "#1a202c" }
    ]

    color_index = crop_name.hash.abs % color_palette.size
    @crop_color_cache[crop_name] = color_palette[color_index]

    @crop_color_cache[crop_name]
  end
end
