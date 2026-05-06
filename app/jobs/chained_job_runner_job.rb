# frozen_string_literal: true

class ChainedJobRunnerJob < ApplicationJob
  queue_as :default

  # chain: [ { "class" => "SomeJob", "args" => { key: value } }, ... ]
  # index: 実行中のインデックス（0始まり）
  def perform(chain:, index: 0)
    unless chain.is_a?(Array) && chain[index]
      Rails.logger.info "ℹ️ [ChainedJobRunnerJob] Chain finished or invalid at index=#{index}"
      return
    end

    current = chain[index]
    job_class_name = current.with_indifferent_access[:class]
    # ActiveJob引数はJSON化で文字列キーになるため、キーワード引数として渡す前に必ずシンボル化
    job_args = (current.with_indifferent_access[:args] || {}).to_h.deep_symbolize_keys
    job_args[:channel_class] = normalize_channel_class(job_args[:channel_class])

    Rails.logger.info "🔗 [ChainedJobRunnerJob] Executing #{index + 1}/#{chain.length}: #{job_class_name} with #{job_args.inspect}"

    job_class = job_class_name.constantize
    # ActiveJobを経由せず直接performを呼ぶことで確実に同期実行し、引数もキーワードで渡す
    job_class.new.perform(**job_args)
    Rails.logger.info "✅ [ChainedJobRunnerJob] Completed: #{job_class_name} (#{index + 1}/#{chain.length})"

    # 次のジョブがあれば自身を再度enqueue
    next_index = index + 1
    if next_index < chain.length
      Rails.logger.info "⏭️ [ChainedJobRunnerJob] Enqueue next: #{chain[next_index].with_indifferent_access[:class]} (#{next_index + 1}/#{chain.length})"
      self.class.perform_later(chain: chain, index: next_index)
    else
      Rails.logger.info "🎉 [ChainedJobRunnerJob] Chain completed (#{chain.length} jobs)"
    end
  end

  private

  def normalize_channel_class(channel_class)
    return channel_class unless channel_class.is_a?(String)
    channel_class.constantize
  rescue NameError => e
    Rails.logger.error "❌ [ChainedJobRunnerJob] Invalid channel_class: #{channel_class} (#{e.message})"
    raise
  end
end
