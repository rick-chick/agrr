# frozen_string_literal: true

module JobArgumentsProvider
  extend ActiveSupport::Concern
  
  # 各ジョブで実装する必要があるメソッド
  # インスタンス変数をハッシュとして返す
  def job_arguments
    raise NotImplementedError, "Each job must implement #job_arguments method"
  end
end
