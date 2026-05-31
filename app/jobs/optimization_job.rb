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

    Rails.logger.info "🚀 [OptimizationJob] Starting optimization for plan ##{cultivation_plan_id}"

    optimizer = Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor.new(
      plan_id: cultivation_plan_id,
      channel_class: channel_class,
      plan_allocation_allocate_gateway: CompositionRoot.plan_allocation_allocate_gateway,
      interaction_rule_gateway: CompositionRoot.interaction_rule_gateway,
      interaction_rule_agrr_format_builder: CompositionRoot.interaction_rule_agrr_format_builder,
      cultivation_plan_gateway: CompositionRoot.cultivation_plan_gateway,
      optimization_plan_read_gateway: CompositionRoot.cultivation_plan_optimization_plan_read_gateway,
      advance_phase_interactor: CompositionRoot.advance_cultivation_plan_phase_interactor,
      logger: CompositionRoot.logger,
      weather_prediction_interactor_factory: lambda { |weather_location:, farm:|
        CompositionRoot.weather_prediction_interactor(weather_location: weather_location, farm: farm)
      },
      clock: Time.zone
    )
    optimizer.call

    # Next chain step is TaskScheduleGenerationJob (task_schedule_generating) or PlanFinalizeJob
    # (completed). Do not broadcast optimization_completed ("generating task schedules…").

    Rails.logger.info "✅ [OptimizationJob] Optimization completed for plan ##{cultivation_plan_id}"
  rescue *(CultivationPlanJobExceptions::OPTIMIZATION_FAILURES) => e
    Rails.logger.error "❌ [OptimizationJob] Failed to optimize plan ##{cultivation_plan_id}: #{e.message}"
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_failed,
      channel_class: channel_class,
      failure_subphase: "optimizing"
    )
    raise
  end
end
