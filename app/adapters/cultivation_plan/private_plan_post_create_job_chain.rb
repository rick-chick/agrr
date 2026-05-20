# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # 私有計画作成成功後の最適化ジョブチェーン起動（Interactor から注入。Presenter は HTTP 表現のみ）。
    class PrivatePlanPostCreateJobChain
      def initialize(job_chain_builder:, job_chain_async_dispatcher:, routes:, channel_class:, caller_label:)
        @job_chain_builder = job_chain_builder
        @job_chain_async_dispatcher = job_chain_async_dispatcher
        @routes = routes
        @channel_class = channel_class
        @caller_label = caller_label
      end

      def enqueue_for_plan(plan_id:)
        jobs = @job_chain_builder.build(
          cultivation_plan_id: plan_id,
          channel_class: @channel_class
        )
        @job_chain_async_dispatcher.enqueue(
          jobs,
          redirect_path: @routes.plan_path(plan_id),
          caller_label: @caller_label
        )
      end
    end
  end
end
