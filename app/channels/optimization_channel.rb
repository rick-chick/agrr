# frozen_string_literal: true

class OptimizationChannel < ApplicationCable::Channel
  def subscribed
    cultivation_plan = CultivationPlan.find(params[:cultivation_plan_id])
    
    # デバッグ情報をログに出力
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan_id=#{params[:cultivation_plan_id]}"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] plan.session_id='#{cultivation_plan.session_id}' (type: #{cultivation_plan.session_id.class})"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] connection.session_id='#{connection.session_id}' (type: #{connection.session_id.class})"
    Rails.logger.info "🔍 [OptimizationChannel#subscribed] Match? #{cultivation_plan.session_id == connection.session_id}"
    
    # セッションIDで認可チェック（開発環境では警告のみ）
    if !authorized?(cultivation_plan)
      if Rails.env.production?
        Rails.logger.warn "🚫 [OptimizationChannel#subscribed] Unauthorized: plan.session_id='#{cultivation_plan.session_id}' != connection.session_id='#{connection.session_id}'"
        reject
        return
      else
        # 開発環境では警告のみ（接続は許可）
        Rails.logger.warn "⚠️ [OptimizationChannel#subscribed] Session mismatch (allowed in dev): plan_id=#{params[:cultivation_plan_id]}"
      end
    end
    
    stream_for cultivation_plan
    
    Rails.logger.info "✅ [OptimizationChannel#subscribed] Authorized! Streaming for plan_id=#{params[:cultivation_plan_id]}"
    
    # 既に完了している場合は即座に通知
    if cultivation_plan.status_completed?
      transmit({ status: 'completed', progress: 100 })
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "🚫 OptimizationChannel: Plan not found: plan_id=#{params[:cultivation_plan_id]}"
    reject
  end
  
  def unsubscribed
    Rails.logger.info "🔌 OptimizationChannel unsubscribed: plan_id=#{params[:cultivation_plan_id]}"
  end
  
  private
  
  def authorized?(cultivation_plan)
    # 公開機能: セッションIDで認可
    # ログインユーザー: user_idでも認可
    cultivation_plan.session_id == connection.session_id ||
      (cultivation_plan.user_id.present? && cultivation_plan.user_id == current_user&.id)
  end
  
  def current_user
    # ApplicationCable::Connectionでユーザー認証を実装する場合はここで取得
    # 現在は公開機能のみなのでnil
    nil
  end
end


