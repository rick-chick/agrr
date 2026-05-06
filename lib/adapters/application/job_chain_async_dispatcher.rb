# frozen_string_literal: true

module Adapters
  module Application
    # 遅延ジョブチェーンのエンキューのみ（ドメインルールなし）。Controller から CompositionRoot 経由で注入する。
    class JobChainAsyncDispatcher
      def initialize(logger:)
        @logger = logger
      end

      # @param job_instances [Array<ActiveJob::Base>]
      # @param redirect_path [String, nil] 完了後リダイレクト用。nil のとき RedirectCompletionJob は付与しない
      # @param caller_label [String] ログ用（従来は controller.class.name）
      def enqueue(job_instances, redirect_path:, caller_label:)
        instances = Array(job_instances)
        @logger.info "🔗 [#{caller_label}] Executing async job chain (sequential via wrapper) with #{instances.length} jobs"
        @logger.info "📋 [#{caller_label}] Job chain: #{instances.map(&:class).map(&:name).join(' → ')}"

        instances = add_redirect_completion_job_if_needed(instances, redirect_path)

        chain = instances.map do |job|
          {
            class: job.class.name,
            args: job.job_arguments
          }
        end

        if chain.empty?
          @logger.info "ℹ️ [#{caller_label}] No jobs to execute in chain"
          return
        end

        @logger.info "🚀 [#{caller_label}] Enqueuing ChainedJobRunnerJob with #{chain.length} steps"
        ChainedJobRunnerJob.perform_later(chain: chain, index: 0)
        @logger.info "🎉 [#{caller_label}] Wrapper enqueued; chain will run sequentially"
      end

      private

      def add_redirect_completion_job_if_needed(job_instances, redirect_path)
        unless redirect_path
          @logger.info "ℹ️ [JobChainAsyncDispatcher] No redirect path specified, skipping redirect completion job"
          return job_instances
        end

        last_job = job_instances.last
        return job_instances unless last_job

        redirect_job = RedirectCompletionJob.new
        redirect_job.channel_id = last_job.cultivation_plan_id
        redirect_job.channel_class = last_job.channel_class
        redirect_job.redirect_path = redirect_path

        @logger.info "🔄 [JobChainAsyncDispatcher] Adding redirect completion job to chain with path: #{redirect_path}"

        job_instances + [ redirect_job ]
      end
    end
  end
end
