# frozen_string_literal: true

class PlansController < CultivationPlanHtmlBaseController
  before_action :authenticate_user!
  layout "application"

  # 基底クラス属性
  self.plan_type = "private"
  self.session_key = :plan_data
  self.redirect_path_method = :plans_path

  # 計画一覧（農場別）
  def index
    presenter = Adapters::CultivationPlan::Presenters::PrivatePlanIndexHtmlPresenter.new(view: self)
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
    presenter = Adapters::CultivationPlan::Presenters::PrivatePlanNewHtmlPresenter.new(view: self)
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
    presenter = Adapters::CultivationPlan::Presenters::PrivatePlanCreateFromSessionHtmlPresenter.new(
      view: self,
      session_key: self.class.session_key
    )
    input_dto = Domain::CultivationPlan::Dtos::PrivatePlanCreateFromSessionInput.new(
      farm_id: parse_positive_route_id(session_data[:farm_id]),
      crop_ids: crop_ids,
      plan_name: session_data[:plan_name],
      total_area: session_data[:total_area],
      user: current_user
    )
    CompositionRoot.private_plan_create_from_session_interactor(
      output_port: presenter,
      session_id_generator: -> { session.id.to_s },
      routes: Adapters::Application::PlanPathRoutesFromController.new(self),
      caller_label: self.class.name,
      select_crop_context_runner: CompositionRoot.private_plan_select_crop_context_runner(
        view: self,
        user_id: current_user.id
      )
    ).call(input_dto)
    return if performed?
  end

  # @deprecated 年度という概念は削除されました。コピー機能は無効化されています。
  # 計画コピー（前年度の計画を新年度にコピー）
  def copy
    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、
    # コピー機能は無効化されました（通年計画と年度ベースの計画の両方）
    # 既存の年度ベースの計画は後方互換性のために保持されますが、
    # 新しい計画は通年計画として作成されるため、コピー機能は不要です
    redirect_to plans_path, alert: I18n.t("plans.errors.copy_not_available_for_annual_planning") and return
  end

  # 計画削除（Undo 対応は Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor へ委譲）
  def destroy
    presenter = Adapters::CultivationPlan::Presenters::CultivationPlanDestroyHtmlPresenter.new(view: self)
    Domain::CultivationPlan::Interactors::CultivationPlanDestroyInteractor.new(
      output_port: presenter,
      user_id: current_user.id,
      gateway: CompositionRoot.cultivation_plan_gateway,
      translator: CompositionRoot.translator,
      user_lookup: CompositionRoot.user_lookup
    ).call(params[:id])
  end

  def spa_plan_detail_url(plan_id)
    "#{spa_frontend_origin}/plans/#{plan_id}"
  end

  def spa_plan_optimizing_url(plan_id)
    "#{spa_plan_detail_url(plan_id)}/optimizing"
  end

  def spa_frontend_origin
    ENV.fetch("FRONTEND_URL", "http://localhost:4200").split(",").map(&:strip).reject(&:empty?).first
  end

  private

  def load_private_plan_select_crop_context(farm_id)
    presenter = Adapters::CultivationPlan::Presenters::PrivatePlanSelectCropHtmlPresenter.new(view: self)
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

  # ルートパラメータの正の整数 ID（計画 :id・作物選択 farm_id 等）。"abc" / 0 / 空白は nil
  def parse_positive_route_id(raw)
    return nil if raw.nil?

    s = raw.is_a?(Integer) ? raw.to_s : raw.to_s.strip
    return nil if s.empty?

    return nil unless s.match?(/\A[1-9]\d*\z/)

    s.to_i
  end

  # 基底クラスで要求されるフックの実装

  def select_crop_redirect_path
    :select_crop_plans_path
  end

  def completion_redirect_path
    :spa_plan_detail_url
  end

  def channel_class
    PlansOptimizationChannel
  end

end
