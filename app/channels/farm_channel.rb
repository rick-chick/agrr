# frozen_string_literal: true

# 農場（Farm）のステータス更新をリアルタイムに配信するチャンネル
class FarmChannel < ApplicationCable::Channel
  def subscribed
    farm = Farm.find(params[:farm_id])
    
    # ユーザー認証チェック（管理者は全アクセス可能、一般ユーザーは自分の農場のみ）
    unless authorized?(farm)
      Rails.logger.warn "🚫 [FarmChannel#subscribed] Unauthorized: farm.user_id=#{farm.user_id} != current_user=#{current_user&.id}"
      reject
      return
    end
    
    stream_for farm
    Rails.logger.info "✅ [FarmChannel#subscribed] Authorized! Streaming for farm_id=#{params[:farm_id]}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "🚫 FarmChannel: Farm not found: farm_id=#{params[:farm_id]}"
    reject
  end

  def unsubscribed
    Rails.logger.info "🔌 FarmChannel unsubscribed: farm_id=#{params[:farm_id]}"
  end

  private

  def authorized?(farm)
    # 管理者、または本人の農場、または参照農場であれば許可
    current_user&.admin? || farm.user_id == current_user&.id || farm.is_reference?
  end

  def current_user
    connection.current_user
  end
end
