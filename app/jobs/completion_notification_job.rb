# frozen_string_literal: true

class CompletionNotificationJob < ApplicationJob
  queue_as :default

  # インスタンス変数の定義
  attr_accessor :cultivation_plan_id, :channel_class

  def perform
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)

    Rails.logger.info "📡 [CompletionNotificationJob] Sending completion notification for plan ##{cultivation_plan_id}"

    begin
      # 最終完了通知
      channel_class.broadcast_to(cultivation_plan, {
        status: "completed",
        progress: 100,
        phase: "completed",
        phase_message: "処理が完了しました",
        message_key: "models.cultivation_plan.phases.completed"
      })

      Rails.logger.info "✅ [CompletionNotificationJob] Completion notification sent for plan ##{cultivation_plan_id}"

    rescue => e
      Rails.logger.error "❌ [CompletionNotificationJob] Failed to send completion notification for plan ##{cultivation_plan_id}: #{e.message}"
      raise
    end
  end
end
