# frozen_string_literal: true

class OptimizeCultivationPlanJob < ApplicationJob
  queue_as :default
  
  # リトライ設定（agrr実行エラー時のみ）
  retry_on Agrr::BaseGateway::ExecutionError, wait: 5.minutes, attempts: 3
  
  # 天気データ不足エラーはリトライしない（データがない限り成功しない）
  discard_on CultivationPlanOptimizer::WeatherDataNotFoundError
  
  def perform(cultivation_plan_id)
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    
    Rails.logger.info "🚀 [OptimizeCultivationPlanJob] Starting optimization for plan ##{cultivation_plan_id}"
    
    optimizer = CultivationPlanOptimizer.new(cultivation_plan)
    
    if optimizer.call
      Rails.logger.info "✅ [OptimizeCultivationPlanJob] Completed for ##{cultivation_plan_id}"
      
      # WebSocketで完了を通知
      broadcast_completion(cultivation_plan)
    else
      Rails.logger.error "❌ [OptimizeCultivationPlanJob] Failed for ##{cultivation_plan_id}"
      broadcast_failure(cultivation_plan)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] CultivationPlan ##{cultivation_plan_id} not found: #{e.message}"
  rescue CultivationPlanOptimizer::WeatherDataNotFoundError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] Weather data not found for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] Please ensure weather data is imported for the farm location"
    cultivation_plan.fail!(e.message)
    broadcast_failure(cultivation_plan)
  rescue Agrr::BaseGateway::ExecutionError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] AGRR command execution failed for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] This may indicate an issue with the agrr binary or input data format"
    
    # ユーザーにわかりやすいエラーメッセージに変換
    user_message = translate_agrr_error(e.message)
    cultivation_plan.fail!(user_message)
    broadcast_failure(cultivation_plan)
  rescue Agrr::BaseGateway::ParseError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] AGRR output parsing failed for ##{cultivation_plan_id}: #{e.message}"
    Rails.logger.error "💡 [OptimizeCultivationPlanJob] This may indicate an issue with the agrr binary output format"
    
    # ユーザーにわかりやすいエラーメッセージに変換
    user_message = translate_agrr_error(e.message)
    cultivation_plan.fail!(user_message)
    broadcast_failure(cultivation_plan)
  rescue StandardError => e
    Rails.logger.error "❌ [OptimizeCultivationPlanJob] Unexpected error for ##{cultivation_plan_id}: #{e.class} - #{e.message}"
    Rails.logger.error "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
    cultivation_plan.fail!("予期しないエラーが発生しました: #{e.message}")
    broadcast_failure(cultivation_plan)
    raise # Re-raise for retry mechanism
  end
  
  private
  
  def translate_agrr_error(error_message)
    case error_message
    when /No candidate reached 100% growth completion/
      "選択された作物が指定期間内に成長完了できません。より長い評価期間を設定するか、異なる作物を選択してください。"
    when /Missing required field/
      "入力データに必須フィールドが不足しています。システム管理者にお問い合わせください。"
    when /FILE_ERROR/
      "ファイルの読み込みに失敗しました。システム管理者にお問い合わせください。"
    when /Invalid input format/
      "入力データの形式が不正です。システム管理者にお問い合わせください。"
    else
      "最適化処理に失敗しました: #{error_message}"
    end
  end
  
  def broadcast_completion(cultivation_plan)
    OptimizationChannel.broadcast_to(
      cultivation_plan,
      {
        status: 'completed',
        progress: cultivation_plan.optimization_progress,
        phase: cultivation_plan.optimization_phase,
        phase_message: cultivation_plan.optimization_phase_message,
        message: '最適化が完了しました'
      }
    )
  rescue => e
    Rails.logger.error "❌ Broadcast completion failed for plan ##{cultivation_plan.id}: #{e.message}"
    # ブロードキャスト失敗はジョブ自体は成功させる（重要度低）
  end
  
  def broadcast_failure(cultivation_plan)
    OptimizationChannel.broadcast_to(
      cultivation_plan,
      {
        status: 'failed',
        progress: cultivation_plan.optimization_progress,
        phase: cultivation_plan.optimization_phase,
        phase_message: cultivation_plan.optimization_phase_message,
        message: '最適化に失敗しました'
      }
    )
  rescue => e
    Rails.logger.error "❌ Broadcast failure failed for plan ##{cultivation_plan.id}: #{e.message}"
    # ブロードキャスト失敗はジョブ自体は成功させる（重要度低）
  end
end

