# frozen_string_literal: true

module JobExecution
  extend ActiveSupport::Concern
  
  # NOTE: このモジュールは個別ジョブに依存させない設計とする
  # ジョブ固有の処理（フェーズ更新など）は各ジョブクラス内で実装する
  # このモジュールは汎用的なジョブチェーン実行のみを提供する
  
  # 遷移先を指定するためのメソッド（各コントローラーでオーバーライド）
  def job_completion_redirect_path
    # デフォルトは何もしない（各コントローラーでオーバーライド）
    nil
  end
  
  # ジョブ完了時の遷移制御
  def handle_job_completion_redirect(cultivation_plan_id, channel_class)
    redirect_path = job_completion_redirect_path
    return unless redirect_path
    
    Rails.logger.info "🔄 [JobExecution] Job completed, redirecting to: #{redirect_path}"
    
    # チャンネル経由でリダイレクト通知を送信
    if channel_class
      cultivation_plan = CultivationPlan.find(cultivation_plan_id)
      channel_class.broadcast_to(
        cultivation_plan,
        {
          type: 'redirect',
          redirect_path: redirect_path,
          message: I18n.t('jobs.weather_prediction.completed')
        }
      )
    end
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
    job_instances + [redirect_job]
  end
  
  private
  
  # 同期的ジョブチェーン実行（従来の方法）
  def execute_job_chain(job_instances)
    Rails.logger.info "🔗 [#{self.class.name}] Executing job chain with #{job_instances.length} jobs"
    Rails.logger.info "📋 [#{self.class.name}] Job chain: #{job_instances.map(&:class).map(&:name).join(' → ')}"
    
    # 各ジョブを順次実行（同期的に確実に順次実行）
    job_instances.each_with_index do |job_instance, index|
      Rails.logger.info "🚀 [#{self.class.name}] Executing job #{index + 1}/#{job_instances.length}: #{job_instance.class.name}"
      
      begin
        # ジョブを実行（引数を渡す）
        job_args = job_instance.job_arguments
        Rails.logger.info "📦 [#{self.class.name}] Job arguments: #{job_args.inspect}"
        job_instance.perform(**job_args)
        
        Rails.logger.info "✅ [#{self.class.name}] Job #{index + 1}/#{job_instances.length} completed: #{job_instance.class.name}"
        
      rescue => e
        Rails.logger.error "❌ [#{self.class.name}] Job #{index + 1}/#{job_instances.length} failed: #{job_instance.class.name}"
        Rails.logger.error "   Error: #{e.message}"
        Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
        raise e
      end
    end
    
    Rails.logger.info "🎉 [#{self.class.name}] All jobs completed successfully"
  end
  
  # 非同期ジョブチェーン実行（新しい方法）
  def execute_job_chain_async(job_instances)
    Rails.logger.info "🔗 [#{self.class.name}] Executing async job chain with #{job_instances.length} jobs"
    Rails.logger.info "📋 [#{self.class.name}] Job chain: #{job_instances.map(&:class).map(&:name).join(' → ')}"
    
    # 遷移制御ジョブを最後に追加
    job_instances = add_redirect_completion_job_if_needed(job_instances)
    
    # 最初のジョブを非同期実行
    if job_instances.any?
      first_job = job_instances.first
      Rails.logger.info "🚀 [#{self.class.name}] Starting async job chain with: #{first_job.class.name}"
      
      # 最初のジョブを非同期実行（キーワード引数として渡す）
      first_job.class.perform_later(**first_job.job_arguments)
      
      # 残りのジョブをチェーンとして設定
      if job_instances.length > 1
        remaining_jobs = job_instances[1..-1]
        Rails.logger.info "🔗 [#{self.class.name}] Setting up chain for #{remaining_jobs.length} remaining jobs"
        
        # 各ジョブを順次チェーンとして設定
        remaining_jobs.each_with_index do |job, index|
          Rails.logger.info "⛓️ [#{self.class.name}] Chaining job #{index + 2}/#{job_instances.length}: #{job.class.name}"
          job.class.perform_later(**job.job_arguments)
        end
      end
    end
    
    Rails.logger.info "🎉 [#{self.class.name}] Async job chain enqueued successfully"
  end
  
  # ジョブインスタンスから非同期チェーンを実行
  def execute_job_chain_from_instances(job_instances)
    Rails.logger.info "🔗 [#{self.class.name}] Converting job instances to async chain"
    
    # 遷移制御ジョブを最後に追加
    job_instances = add_redirect_completion_job_if_needed(job_instances)
    
    # ジョブインスタンスを非同期実行用に変換
    job_instances.each_with_index do |job_instance, index|
      Rails.logger.info "🚀 [#{self.class.name}] Enqueuing job #{index + 1}/#{job_instances.length}: #{job_instance.class.name}"
      
      # ジョブインスタンスのjob_argumentsメソッドを使ってハッシュを取得
      job_args = job_instance.job_arguments
      Rails.logger.info "📦 [#{self.class.name}] Job arguments: #{job_args.inspect}"
      
      job_instance.class.perform_later(**job_args)
    end
    
    Rails.logger.info "🎉 [#{self.class.name}] All jobs enqueued for async execution"
  end
end
