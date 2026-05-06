# frozen_string_literal: true

# プレーン Ruby モジュール（`ActiveSupport::Concern` は不要）
module JobArgumentsProvider
  # 各ジョブで実装する必要があるメソッド
  # インスタンス変数をハッシュとして返す
  def job_arguments
    raise NotImplementedError, "Each job must implement #job_arguments method"
  end
end
