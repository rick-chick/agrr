# frozen_string_literal: true

# Public Plans（匿名ユーザー向け）専用の最適化チャンネル
# Private Plans（認証ユーザー向け）は PlansOptimizationChannel を使用
class OptimizationChannel < ApplicationCable::Channel
  def subscribed
    cultivation_plan = CultivationPlan.find_by(id: params[:cultivation_plan_id])
    unless cultivation_plan
      Rails.logger.warn "🚫 OptimizationChannel: Plan not found: plan_id=#{params[:cultivation_plan_id]}"
      reject
      return
    end

    # デバッグ情報をログに出力
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan_id=#{params[:cultivation_plan_id]}"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan.plan_type='#{cultivation_plan.plan_type}'"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan.session_id='#{cultivation_plan.session_id}'"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan.user_id=#{cultivation_plan.user_id}"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] connection.session_id='#{connection.session_id}'"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] connection.current_user=#{current_user&.id}"

    # セッションIDまたはログインユーザーで認可チェック（未認可は常に拒否）
    unless authorized?(cultivation_plan)
      Rails.logger.warn "🚫 [OptimizationChannel#subscribed] Unauthorized: plan.session_id='#{cultivation_plan.session_id}' != connection.session_id='#{connection.session_id}'"
      reject
      return
    end

    stream_for cultivation_plan

    Rails.logger.info "✅ [OptimizationChannel#subscribed] Authorized! Streaming for plan_id=#{params[:cultivation_plan_id]}"

    # 既に完了している場合は即座に通知
    if cultivation_plan.status_completed?
      transmit({ status: "completed", progress: 100 })
    end
  end

  def unsubscribed
    Rails.logger.info "🔌 OptimizationChannel unsubscribed: plan_id=#{params[:cultivation_plan_id]}"
  end

  private

  def authorized?(cultivation_plan)
    # Public計画: plan_type が public であれば認可（匿名ユーザー向け専用チャンネル）
    if cultivation_plan.plan_type_public?
      Rails.logger.info "🔍 [OptimizationChannel#authorized?] public plan → authorized"
      return true
    end

    # Private計画が来た場合（通常はPlansOptimizationChannelを使うべき）: session/userで認可
    session_authorized = cultivation_plan.session_id.present? && cultivation_plan.session_id == connection.session_id
    user_authorized = cultivation_plan.user_id.present? && cultivation_plan.user_id == current_user&.id

    authorized = session_authorized || user_authorized

    Rails.logger.info "🔍 [OptimizationChannel#authorized?] session_authorized=#{session_authorized}, user_authorized=#{user_authorized}, result=#{authorized}"

    authorized
  end

  def current_user
    # ApplicationCable::Connectionで設定されたユーザーを取得
    connection.current_user
  end
end
