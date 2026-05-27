# frozen_string_literal: true

# PlanAllocationAdjustInteractor の AR 統合テスト用。
module PlanAllocationAdjustTestSupport
  class AdjustResultCollector < Domain::CultivationPlan::Ports::PlanAllocationAdjustOutputPort
    attr_reader :output, :failure

    def on_success(output:)
      @output = output
      @failure = nil
    end

    def on_failure(failure:)
      @failure = failure
      @output = nil
    end

    def success?
      failure.nil?
    end

    def message
      failure&.message || output&.message
    end
  end

  def run_plan_allocation_adjust(plan_id:, moves:, clock: Time.zone)
    collector = AdjustResultCollector.new
    CompositionRoot.build_plan_allocation_adjust_interactor(output_port: collector, clock: clock).call(
      Domain::CultivationPlan::Dtos::PlanAllocationAdjustInput.new(plan_id: plan_id, moves: moves)
    )
    collector
  end
end
