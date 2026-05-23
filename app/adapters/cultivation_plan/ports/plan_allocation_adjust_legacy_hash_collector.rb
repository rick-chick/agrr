# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # レガシー Hash 契約（add_crop / integration）向けの adjust 結果収集。
      class PlanAllocationAdjustLegacyHashCollector < Domain::CultivationPlan::Ports::PlanAllocationAdjustOutputPort
        attr_reader :payload

        def on_success(output:)
          @payload = {
            success: true,
            message: output.message,
            skipped: output.skipped
          }
          if output.cultivation_plan
            @payload[:cultivation_plan] = output.cultivation_plan
          end
        end

        def on_failure(failure:)
          @payload = {
            success: false,
            message: failure.message,
            status: Mappers::PlanAllocationAdjustFailureHttpMapper.http_status_for(failure.kind)
          }
        end

        def to_h
          @payload
        end
      end
    end
  end
end
