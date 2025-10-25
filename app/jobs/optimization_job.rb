# frozen_string_literal: true

require_relative 'concerns/job_arguments_provider'

class OptimizationJob < ApplicationJob
  include JobArgumentsProvider
  
  queue_as :default
  
  # インスタンス変数の定義
  attr_accessor :cultivation_plan_id, :channel_class
  
  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end
  
  def perform(cultivation_plan_id: nil, channel_class: nil)
    # dictの中身を確認してバリデーション
    Rails.logger.info "🔍 [OptimizationJob] Received args: cultivation_plan_id=#{cultivation_plan_id}, channel_class=#{channel_class}"
    
    # 引数が渡された場合はそれを使用、そうでなければインスタンス変数から取得
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class
    
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    
    Rails.logger.info "🚀 [OptimizationJob] Starting optimization for plan ##{cultivation_plan_id}"
    
    begin
      # 最適化開始通知
      cultivation_plan.phase_optimizing!(channel_class)
      
      # 最適化処理
      optimizer = CultivationPlanOptimizer.new(cultivation_plan, channel_class)
      optimizer.call
      
      # 最適化完了通知
      cultivation_plan.phase_completed!(channel_class)
      cultivation_plan.complete!
      
      Rails.logger.info "✅ [OptimizationJob] Optimization completed for plan ##{cultivation_plan_id}"
      
    rescue => e
      Rails.logger.error "❌ [OptimizationJob] Failed to optimize plan ##{cultivation_plan_id}: #{e.message}"
      cultivation_plan.phase_failed!('optimizing', channel_class)
      raise
    end
  end
end
