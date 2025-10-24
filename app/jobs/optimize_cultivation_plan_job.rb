# frozen_string_literal: true

class OptimizeCultivationPlanJob < ApplicationJob
  queue_as :default
  
  # リトライ設定（agrr実行エラー時のみ）
  retry_on Agrr::BaseGateway::ExecutionError, wait: 5.minutes, attempts: 3
  
  # 天気データ不足エラーはリトライしない（データがない限り成功しない）
  discard_on CultivationPlanOptimizer::WeatherDataNotFoundError
  
  def perform(cultivation_plan_id, channel_class = OptimizationChannel)
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    
    Rails.logger.info "🚀 [OptimizeCultivationPlanJob] Starting optimization for plan ##{cultivation_plan_id}"
    
    # 天気予測を先に実行
    weather_prediction_service = WeatherPredictionService.new(cultivation_plan.farm)
    existing_prediction = weather_prediction_service.get_existing_prediction(cultivation_plan: cultivation_plan)
    
    unless existing_prediction
      Rails.logger.info "🌤️ [OptimizeCultivationPlanJob] No existing weather prediction, creating new one"
      weather_prediction_service.predict_for_cultivation_plan(cultivation_plan)
    else
      Rails.logger.info "♻️ [OptimizeCultivationPlanJob] Using existing weather prediction"
    end
    
    # 最適化実行
    optimizer = CultivationPlanOptimizer.new(cultivation_plan, channel_class)
    optimizer.call
    
    Rails.logger.info "✅ [OptimizeCultivationPlanJob] Completed for ##{cultivation_plan_id}"
    broadcast_completion(cultivation_plan, channel_class)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] CultivationPlan ##{cultivation_plan_id} not found: #{e.message}"
  rescue CultivationPlanOptimizer::WeatherDataNotFoundError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] Weather data not found for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] Please ensure weather data is imported for the farm location"
    cultivation_plan.fail!(e.message)
    broadcast_failure(cultivation_plan)
  rescue Agrr::BaseGateway::NoAllocationCandidatesError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] AGRR allocation failed for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.info "🔄 [OptimizeCultivationPlanJob] Translating error to user-friendly message"
    
    # ユーザーフレンドリーなエラーメッセージに変換
    user_message = translate_agrr_error(e.message)
    cultivation_plan.fail!(user_message)
    broadcast_failure(cultivation_plan, channel_class)
  rescue Agrr::BaseGateway::ExecutionError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] AGRR command execution failed for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] This may indicate an issue with the agrr binary or input data format"
    Rails.logger.info "🔄 [OptimizeCultivationPlanJob] Translating error to user-friendly message"
    
    # ユーザーにわかりやすいエラーメッセージに変換
    user_message = translate_agrr_error(e.message)
    cultivation_plan.fail!(user_message)
    broadcast_failure(cultivation_plan, channel_class)
  rescue Agrr::BaseGateway::ParseError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] AGRR output parsing failed for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] This may indicate an issue with the agrr binary output format"
    Rails.logger.info "🔄 [OptimizeCultivationPlanJob] Translating error to user-friendly message"
    
    # ユーザーにわかりやすいエラーメッセージに変換
    user_message = translate_agrr_error(e.message)
    cultivation_plan.fail!(user_message)
    broadcast_failure(cultivation_plan, channel_class)
  rescue StandardError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] Unexpected error for ##{cultivation_plan_id}: #{e.class} - #{e.message}"
    Rails.logger.error "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
    Rails.logger.info "🔄 [OptimizeCultivationPlanJob] Translating error to user-friendly message"
    
    cultivation_plan.fail!(I18n.t('jobs.optimize_cultivation_plan.unexpected_error', message: e.message))
    broadcast_failure(cultivation_plan, channel_class)
    raise # Re-raise for retry mechanism
  end
  
  private
  
  def translate_agrr_error(error_message)
    case error_message
    when /No candidate reached 100% growth completion/
      I18n.t('jobs.optimize_cultivation_plan.errors.growth_incomplete')
    when /No valid allocation candidates could be generated/
      <<~MSG.strip
        作付け計画の候補を生成できませんでした。以下の可能性があります：
        
        1. 計画期間内に作物が成熟しない
           → 計画期間を延長するか、より短期間で収穫できる作物を選択してください
        
        2. 圃場の面積が不足している
           → 圃場の面積を増やすか、作物の数を減らしてください
        
        3. 気象条件が適していない
           → 選択した作物が気象条件に適していない可能性があります。別の作物を試してください
        
        4. 作物の収益設定が適切でない
           → 作物の収益設定（revenue_per_area）を確認してください
      MSG
    when /Missing required field/
      I18n.t('jobs.optimize_cultivation_plan.errors.missing_field')
    when /FILE_ERROR/
      I18n.t('jobs.optimize_cultivation_plan.errors.file_error')
    when /Invalid input format/
      I18n.t('jobs.optimize_cultivation_plan.errors.invalid_format')
    else
      I18n.t('jobs.optimize_cultivation_plan.errors.optimization_failed', message: error_message)
    end
  end
  
  def broadcast_completion(cultivation_plan, channel_class)
    broadcast_to_channel(
      cultivation_plan,
      channel_class,
      {
        status: 'completed',
        progress: cultivation_plan.optimization_progress,
        phase: cultivation_plan.optimization_phase,
        phase_message: cultivation_plan.optimization_phase_message,
        message: I18n.t('jobs.optimize_cultivation_plan.completed')
      }
    )
  rescue => e
    Rails.logger.error "❌ Broadcast completion failed for plan ##{cultivation_plan.id}: #{e.message}"
    # ブロードキャスト失敗はジョブ自体は成功させる（重要度低）
  end
  
  def broadcast_failure(cultivation_plan, channel_class)
    return if @broadcasted_failure
    @broadcasted_failure = true
    
    broadcast_to_channel(
      cultivation_plan,
      channel_class,
      {
        status: 'failed',
        progress: cultivation_plan.optimization_progress,
        phase: cultivation_plan.optimization_phase,
        phase_message: cultivation_plan.optimization_phase_message,
        message: cultivation_plan.error_message || I18n.t('jobs.optimize_cultivation_plan.failed')
      }
    )
  rescue => e
    Rails.logger.error "❌ Broadcast failure failed for plan ##{cultivation_plan.id}: #{e.message}"
    # ブロードキャスト失敗はジョブ自体は成功させる（重要度低）
  end
  
  # 指定されたチャンネルにブロードキャスト
  def broadcast_to_channel(cultivation_plan, channel_class, message)
    Rails.logger.info "📡 Broadcasting to #{channel_class.name} for plan ##{cultivation_plan.id}"
    channel_class.broadcast_to(cultivation_plan, message)
  end
end

