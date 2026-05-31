# frozen_string_literal: true

module Adapters
  module CultivationPlan
    class ApiPrivatePlanJobChainEnqueuer
      def initialize(job_chain_builder:, advance_phase_interactor:)
        @job_chain_builder = job_chain_builder
        @advance_phase_interactor = advance_phase_interactor
      end

      def enqueue_after_create(cultivation_plan_id:)
        @advance_phase_interactor.call(
          Domain::CultivationPlan::Dtos::AdvanceCultivationPlanPhaseInput.new(
            plan_id: cultivation_plan_id,
            phase_name: :start_optimizing,
            channel_class: PlansOptimizationChannel
          )
        )

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
