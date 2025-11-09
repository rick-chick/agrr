require_relative 'concerns/job_arguments_provider'

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
    cultivation_plan = nil

    unless cultivation_plan_id
      Rails.logger.warn '⚠️ [TaskScheduleGenerationJob] cultivation_plan_id が指定されていません'
      return
    end

    Rails.logger.info "🗓️ [TaskScheduleGenerationJob] Start generation for CultivationPlan##{cultivation_plan_id}"

    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    cultivation_plan.phase_task_schedule_generating!(channel_class)

    task_schedule_generator.generate!(cultivation_plan_id: cultivation_plan_id)

    cultivation_plan.complete!
    cultivation_plan.phase_completed!(channel_class)

    Rails.logger.info "✅ [TaskScheduleGenerationJob] Completed generation for CultivationPlan##{cultivation_plan_id}"
  rescue TaskScheduleGeneratorService::WeatherDataMissingError,
         TaskScheduleGeneratorService::ProgressDataMissingError,
         TaskScheduleGeneratorService::GddTriggerMissingError => e
    Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] Failed CultivationPlan##{cultivation_plan_id}: #{e.message}"
    handle_failure(cultivation_plan, channel_class, e)
    raise
  rescue TaskScheduleGeneratorService::Error => e
    Rails.logger.error "❌ [TaskScheduleGenerationJob] Failed for CultivationPlan##{cultivation_plan_id}: #{e.message}"
    handle_failure(cultivation_plan, channel_class, e)
    raise
  end

  private

  def task_schedule_generator
    @task_schedule_generator ||= TaskScheduleGeneratorService.new
  end

  def handle_failure(cultivation_plan, channel_class, error)
    return unless cultivation_plan

    Rails.logger.error "❌ [TaskScheduleGenerationJob] Handling failure for CultivationPlan##{cultivation_plan.id}: #{error.message}"
    cultivation_plan.phase_failed!('task_schedule_generation', channel_class)
  end
end
