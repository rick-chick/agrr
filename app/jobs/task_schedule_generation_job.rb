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

    unless cultivation_plan_id
      Rails.logger.warn '⚠️ [TaskScheduleGenerationJob] cultivation_plan_id が指定されていません'
      return
    end

    Rails.logger.info "🗓️ [TaskScheduleGenerationJob] Start generation for CultivationPlan##{cultivation_plan_id}"

    task_schedule_generator.generate!(cultivation_plan_id: cultivation_plan_id)

    Rails.logger.info "✅ [TaskScheduleGenerationJob] Completed generation for CultivationPlan##{cultivation_plan_id}"
  rescue TaskScheduleGeneratorService::WeatherDataMissingError,
         TaskScheduleGeneratorService::ProgressDataMissingError => e
    Rails.logger.warn "⚠️ [TaskScheduleGenerationJob] Skipped CultivationPlan##{cultivation_plan_id}: #{e.message}"
  rescue TaskScheduleGeneratorService::Error => e
    Rails.logger.error "❌ [TaskScheduleGenerationJob] Failed for CultivationPlan##{cultivation_plan_id}: #{e.message}"
    raise
  end

  private

  def task_schedule_generator
    @task_schedule_generator ||= TaskScheduleGeneratorService.new
  end
end

