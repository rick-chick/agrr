# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAddCropAdjustInvokeActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAddCropAdjustInvokeGateway
        def initialize(logger:)
          super(logger: logger)
        end

        # optimization_host は attach 済みの plan を保持すること。
        def adjust_with_moves!(optimization_host:, plan_id:, moves:)
          cultivation_plan = ::CultivationPlan.find(plan_id)
          optimization_host.adjust_with_db_weather(cultivation_plan, moves)
        end
      end
    end
  end
end
