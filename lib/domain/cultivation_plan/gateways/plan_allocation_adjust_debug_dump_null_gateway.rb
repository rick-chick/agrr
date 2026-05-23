# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustDebugDumpNullGateway < PlanAllocationAdjustDebugDumpGateway
        def dump_payload!(current_allocation:, moves:, fields:, crops:)
          nil
        end
      end
    end
  end
end
