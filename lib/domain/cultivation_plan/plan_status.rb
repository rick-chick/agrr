# frozen_string_literal: true

module Domain
  module CultivationPlan
    # CultivationPlan#status（文字列 / シンボル / 列挙の読み取り値）の比較を一箇所に寄せる。
    module PlanStatus
      OPTIMIZING = "optimizing"

      module_function

      def optimizing?(status)
        status.to_s == OPTIMIZING
      end
    end
  end
end
