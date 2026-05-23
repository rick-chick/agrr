# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 開発時 adjust 入力のファイルダンプ（本番は Null 実装）。
      class PlanAllocationAdjustDebugDumpGateway
        # @param current_allocation [Hash]
        # @param moves [Array<Hash>]
        # @param fields [Array]
        # @param crops [Array]
        def dump_payload!(current_allocation:, moves:, fields:, crops:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
