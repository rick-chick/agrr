# frozen_string_literal: true

require_relative "concerns/job_arguments_provider"

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
      # フェーズ遷移（status / optimization_phase / broadcast）は CultivationPlanOptimizeInteractor に集約

      # 最適化処理
      optimizer = Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor.new(
        plan_id: cultivation_plan_id,
        channel_class: channel_class,
        allocation_gateway: CompositionRoot.plan_allocation_gateway,
        interaction_rule_gateway: CompositionRoot.interaction_rule_gateway,
        cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
        logger: CompositionRoot.logger,
        weather_prediction_interactor_factory: lambda { |weather_location:, farm:|
          CompositionRoot.weather_prediction_interactor(weather_location: weather_location, farm: farm)
        },
        clock: Time.zone
      )
      optimizer.call

      # 最適化完了通知（作業予定生成へ移行）
      cultivation_plan.phase_optimization_completed!(channel_class)

      Rails.logger.info "✅ [OptimizationJob] Optimization completed for plan ##{cultivation_plan_id}"

    rescue => e
      Rails.logger.error "❌ [OptimizationJob] Failed to optimize plan ##{cultivation_plan_id}: #{e.message}"
      cultivation_plan.phase_failed!("optimizing", channel_class)
      raise
    end
  end
end
