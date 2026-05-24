# frozen_string_literal: true

class PlansController < CultivationPlanHtmlBaseController
  before_action :authenticate_user!
  layout "application"

  # レガシー HTML 一覧は SPA へリダイレクト（Phase 5 でルートごと削除予定）
  def index
    redirect_to spa_private_plans_path, allow_other_host: true
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

  def spa_private_plans_path
    "#{spa_frontend_origin}/plans"
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
end
