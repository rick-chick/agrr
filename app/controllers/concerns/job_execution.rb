# frozen_string_literal: true

module JobExecution
  # NOTE: このモジュールは個別ジョブに依存させない設計とする
  # ジョブ固有の処理（フェーズ更新など）は各ジョブクラス内で実装する
  # このモジュールは汎用的なジョブチェーン実行のみを提供する

  # 遷移先を指定するためのメソッド（各コントローラーでオーバーライド）
  def job_completion_redirect_path
    # デフォルトは何もしない（各コントローラーでオーバーライド）
    nil
  end

  # 遷移制御ジョブを必要に応じて追加
  def add_redirect_completion_job_if_needed(job_instances)
    # コントローラーインスタンスが存在する場合のみ遷移制御ジョブを追加
    redirect_path = job_completion_redirect_path
    unless redirect_path
      Rails.logger.info "ℹ️ [JobExecution] No redirect path specified, skipping redirect completion job"
      return job_instances
    end

    # 最後のジョブから必要な情報を取得
    last_job = job_instances.last
    return job_instances unless last_job

    # RedirectCompletionJobを作成
    redirect_job = RedirectCompletionJob.new
    redirect_job.channel_id = last_job.cultivation_plan_id  # チャンネル用のIDとして使用
    redirect_job.channel_class = last_job.channel_class
    redirect_job.redirect_path = redirect_path

    Rails.logger.info "🔄 [JobExecution] Adding redirect completion job to chain with path: #{redirect_path}"

    # ジョブチェーンの最後に追加
    job_instances + [ redirect_job ]
  end

  private

  # 非同期ジョブチェーン実行（新しい方法）
  def execute_job_chain_async(job_instances)
    Rails.logger.info "🔗 [#{self.class.name}] Executing async job chain (sequential via wrapper) with #{job_instances.length} jobs"
    Rails.logger.info "📋 [#{self.class.name}] Job chain: #{job_instances.map(&:class).map(&:name).join(' → ')}"

    # 遷移制御ジョブを最後に追加
    job_instances = add_redirect_completion_job_if_needed(job_instances)

    # ラッパー用のchain配列に変換
    chain = job_instances.map do |job|
      {
        class: job.class.name,
        args: job.job_arguments
      }
    end

    if chain.empty?
      Rails.logger.info "ℹ️ [#{self.class.name}] No jobs to execute in chain"
      return
    end

    Rails.logger.info "🚀 [#{self.class.name}] Enqueuing ChainedJobRunnerJob with #{chain.length} steps"
    ChainedJobRunnerJob.perform_later(chain: chain, index: 0)
    Rails.logger.info "🎉 [#{self.class.name}] Wrapper enqueued; chain will run sequentially"
  end
end
