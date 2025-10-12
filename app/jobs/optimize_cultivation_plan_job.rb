# frozen_string_literal: true

class OptimizeCultivationPlanJob < ApplicationJob
  queue_as :default
  
  # リトライ設定（agrr実行エラー時のみ）
  retry_on Agrr::BaseGateway::ExecutionError, wait: 5.minutes, attempts: 3
  
  # 天気データ不足エラーはリトライしない（データがない限り成功しない）
  discard_on CultivationPlanOptimizer::WeatherDataNotFoundError
  
  def perform(cultivation_plan_id)
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    
    optimizer = CultivationPlanOptimizer.new(cultivation_plan)
    
    if optimizer.call
      Rails.logger.info "✅ OptimizeCultivationPlanJob completed for ##{cultivation_plan_id}"
    else
      Rails.logger.error "❌ OptimizeCultivationPlanJob failed for ##{cultivation_plan_id}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ CultivationPlan ##{cultivation_plan_id} not found: #{e.message}"
  rescue CultivationPlanOptimizer::WeatherDataNotFoundError => e
    Rails.logger.error "❌ OptimizeCultivationPlanJob aborted for ##{cultivation_plan_id}: #{e.message}"
    cultivation_plan.fail!(e.message)
  end
end

