# frozen_string_literal: true

require_relative "concerns/job_arguments_provider"

class PlanFinalizeJob < ApplicationJob
  include JobArgumentsProvider

  queue_as :default

  attr_accessor :cultivation_plan_id, :channel_class

  def job_arguments
    {
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end

  def perform(cultivation_plan_id: nil, channel_class: nil)
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class

    unless cultivation_plan_id
      Rails.logger.warn "⚠️ [PlanFinalizeJob] cultivation_plan_id が指定されていません"
      return
    end

    Rails.logger.info "🧩 [PlanFinalizeJob] Finalizing CultivationPlan##{cultivation_plan_id}"

    CompositionRoot.cultivation_plan_gateway.update(cultivation_plan_id, { status: "completed" })
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_completed,
      channel_class: channel_class
    )

    Rails.logger.info "✅ [PlanFinalizeJob] Finalized CultivationPlan##{cultivation_plan_id}"
  rescue *(CultivationPlanJobExceptions::PLAN_FINALIZE_FAILURES) => e
    Rails.logger.error "❌ [PlanFinalizeJob] Failed to finalize plan ##{cultivation_plan_id}: #{e.message}"
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_failed,
      channel_class: channel_class,
      failure_subphase: "task_schedule_generation"
    )
    raise
  end
end
