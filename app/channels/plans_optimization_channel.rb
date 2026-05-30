# frozen_string_literal: true

# Private Plans（認証ユーザー向け）専用の最適化チャンネル
class PlansOptimizationChannel < ApplicationCable::Channel
  def subscribed
    cultivation_plan = CultivationPlan.find_by(id: params[:cultivation_plan_id])
    unless cultivation_plan
      Rails.logger.warn "🚫 PlansOptimizationChannel: Plan not found: plan_id=#{params[:cultivation_plan_id]}"
      reject
      return
    end

    # デバッグ情報をログに出力
    Rails.logger.info "🔍 [PlansOptimizationChannel#subscribed] plan_id=#{params[:cultivation_plan_id]}"
    Rails.logger.info "🔍 [PlansOptimizationChannel#subscribed] plan.plan_type='#{cultivation_plan.plan_type}'"
    Rails.logger.info "🔍 [PlansOptimizationChannel#subscribed] plan.user_id=#{cultivation_plan.user_id}"
    Rails.logger.info "🔍 [PlansOptimizationChannel#subscribed] connection.current_user=#{current_user&.id}"

    # Private計画であることを確認
    unless cultivation_plan.plan_type_private?
      Rails.logger.warn "🚫 [PlansOptimizationChannel#subscribed] Not a private plan"
      reject
      return
    end

    # ユーザー認証チェック
    unless authorized?(cultivation_plan)
      Rails.logger.warn "🚫 [PlansOptimizationChannel#subscribed] Unauthorized: plan.user_id=#{cultivation_plan.user_id} != current_user=#{current_user&.id}"
      reject
      return
    end

    stream_for cultivation_plan

    Rails.logger.info "✅ [PlansOptimizationChannel#subscribed] Authorized! Streaming for plan_id=#{params[:cultivation_plan_id]}"

    snapshot = Adapters::CultivationPlan::OptimizationSubscriptionSnapshot.payload_for(cultivation_plan)
    transmit(snapshot) if snapshot.present?
  end

  def unsubscribed
    Rails.logger.info "🔌 PlansOptimizationChannel unsubscribed: plan_id=#{params[:cultivation_plan_id]}"
  end

  private

  def authorized?(cultivation_plan)
    # Private計画: user_idで認可（ログインユーザーのみ）
    user_authorized = cultivation_plan.user_id.present? && cultivation_plan.user_id == current_user&.id

    Rails.logger.info "🔍 [PlansOptimizationChannel#authorized?] user_authorized=#{user_authorized}"

    user_authorized
  end

  def current_user
    # ApplicationCable::Connectionで設定されたユーザーを取得
    connection.current_user
  end
end
