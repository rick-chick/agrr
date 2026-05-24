require_relative "concerns/job_arguments_provider"

class TaskScheduleGenerationJob < ApplicationJob
  include JobArgumentsProvider

  queue_as :default

  attr_accessor :cultivation_plan_id, :channel_class
  attr_writer :task_schedule_generator

  def job_arguments
    {
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end

  def perform(cultivation_plan_id: nil, channel_class: nil)
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class

    self.channel_class = channel_class

    unless cultivation_plan_id
      Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] cultivation_plan_id が指定されていません"
      return
    end

    Rails.logger.info "🗓️ [TaskScheduleGenerationJob] Start generation for CultivationPlan##{cultivation_plan_id}"

    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_task_schedule_generating,
      channel_class: channel_class
    )

    task_schedule_generator.generate!(cultivation_plan_id: cultivation_plan_id)

    CompositionRoot.cultivation_plan_gateway.update(cultivation_plan_id, { status: "completed" })
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_completed,
      channel_class: channel_class
    )

    Rails.logger.info "✅ [TaskScheduleGenerationJob] Completed generation for CultivationPlan##{cultivation_plan_id}"
  rescue Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor::TemplateMissingError => e
    Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] Template missing for CultivationPlan##{cultivation_plan_id}: #{e.message}"
    handle_template_missing(cultivation_plan_id, channel_class, e)
  rescue Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor::WeatherDataMissingError,
         Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor::ProgressDataMissingError,
         Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor::GddTriggerMissingError => e
    Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] Failed CultivationPlan##{cultivation_plan_id}: #{e.message}"
    handle_failure(cultivation_plan_id, channel_class, e)
    raise
  rescue Domain::AgriculturalTask::Interactors::TaskScheduleGenerateInteractor::Error => e
    Rails.logger.error "❌ [TaskScheduleGenerationJob] Failed for CultivationPlan##{cultivation_plan_id}: #{e.message}"
    handle_failure(cultivation_plan_id, channel_class, e)
    raise
  end

  private

  def task_schedule_generator
    @task_schedule_generator ||= CompositionRoot.task_schedule_generate_interactor
  end

  def finalize_plan_completed(plan_id, channel_class)
    CompositionRoot.cultivation_plan_gateway.update(plan_id, { status: "completed" })
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: plan_id,
      phase_name: :phase_completed,
      channel_class: channel_class
    )
  end

  def handle_failure(plan_id, channel_class, error)
    return unless plan_id

    Rails.logger.error "❌ [TaskScheduleGenerationJob] Handling failure for CultivationPlan##{plan_id}: #{error.message}"
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: plan_id,
      phase_name: :phase_failed,
      channel_class: channel_class,
      failure_subphase: "task_schedule_generation"
    )
  end

  def handle_template_missing(plan_id, channel_class, error)
    return unless plan_id

    Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] Handling template missing for CultivationPlan##{plan_id}: #{error.message}"

    # 計画を完了状態にする（テンプレートがない場合でも計画は完成させる）
    # トーストはresults画面で表示されるため、ここでは通常の完了通知のみ送信
    finalize_plan_completed(plan_id, channel_class)
  rescue *(CultivationPlanJobExceptions::TASK_SCHEDULE_TEMPLATE_COMPLETION_FAILURES) => e
    Rails.logger.error "❌ [TaskScheduleGenerationJob] Failed to handle template missing: #{e.message}"
    finalize_plan_completed(plan_id, channel_class) if plan_id
  end
end
