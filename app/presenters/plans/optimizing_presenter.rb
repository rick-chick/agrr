# frozen_string_literal: true

module Plans
  class OptimizingPresenter
    def initialize(plan_id:)
      @plan_id = plan_id
    end

    def plan
      @plan ||= CultivationPlan.find(@plan_id)
    end

    def plan_id
      @plan_id
    end

    def status
      plan.status
    end
  end
end


