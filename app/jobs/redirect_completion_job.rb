# frozen_string_literal: true

require_relative 'concerns/job_arguments_provider'

class RedirectCompletionJob < ApplicationJob
  include JobArgumentsProvider
  
  queue_as :default
  
  # インスタンス変数の定義
  attr_accessor :channel_id, :channel_class, :redirect_path
  
  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      channel_id: channel_id,
      channel_class: channel_class,
      redirect_path: redirect_path
    }
  end
  
  def perform(channel_id: nil, channel_class: nil, redirect_path: nil)
    # dictの中身を確認してバリデーション
    Rails.logger.info "🔍 [RedirectCompletionJob] Received args: channel_id=#{channel_id}, channel_class=#{channel_class}, redirect_path=#{redirect_path}"
    
    # 引数が渡された場合はそれを使用、そうでなければインスタンス変数から取得
    channel_id ||= self.channel_id
    channel_class ||= self.channel_class
    redirect_path ||= self.redirect_path
    
    unless redirect_path
      Rails.logger.error "❌ [RedirectCompletionJob] No redirect path specified! This should not happen."
      Rails.logger.error "   channel_id: #{channel_id}, channel_class: #{channel_class}"
      raise ArgumentError, "redirect_path is required but was nil"
    end
    
    Rails.logger.info "🔄 [RedirectCompletionJob] Sending redirect notification for channel ##{channel_id}"
    
    # チャンネル経由でリダイレクト通知を送信
    # channel_idはCultivationPlanのIDなので、オブジェクトを取得してから送信
    if channel_class
      cultivation_plan = CultivationPlan.find(channel_id)
      channel_class.broadcast_to(
        cultivation_plan,  # ← CultivationPlanオブジェクトを渡す
        {
          type: 'redirect',
          redirect_path: redirect_path,
          message: I18n.t('jobs.weather_prediction.completed')
        }
      )
    end
    
    Rails.logger.info "✅ [RedirectCompletionJob] Redirect notification sent for channel ##{channel_id}"
  end
end




