# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # add_crop 向け: PlanAllocationAdjust の結果を AddCropAdjustResult に写す output_port。
      class AddCropAdjustResultCollector < Domain::CultivationPlan::Ports::PlanAllocationAdjustOutputPort
        attr_reader :add_crop_adjust_result

        def on_success(output:)
          @add_crop_adjust_result = Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(
            success: true,
            message: output.message,
            skipped: output.skipped
          )
        end

        def on_failure(failure:)
          @add_crop_adjust_result = Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(
            success: false,
            message: failure.message,
            http_status: Mappers::PlanAllocationAdjustFailureHttpMapper.http_status_for(failure.kind)
          )
        end
      end
    end
  end
end
