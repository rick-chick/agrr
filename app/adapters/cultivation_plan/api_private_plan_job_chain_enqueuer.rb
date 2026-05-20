# frozen_string_literal: true

module Adapters
  module CultivationPlan
    class ApiPrivatePlanJobChainEnqueuer
      def initialize(job_chain_builder:)
        @job_chain_builder = job_chain_builder
      end

      def enqueue_after_create(cultivation_plan_id:)
        job_instances = @job_chain_builder.build(
          cultivation_plan_id: cultivation_plan_id,
          channel_class: PlansOptimizationChannel
        )

        chain = job_instances.map do |job|
          {
            class: job.class.name,
            args: job.job_arguments
          }
        end

        ChainedJobRunnerJob.perform_later(chain: chain, index: 0)
      end
    end
  end
end
