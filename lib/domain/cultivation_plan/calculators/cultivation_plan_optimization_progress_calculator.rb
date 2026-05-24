# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      module CultivationPlanOptimizationProgressCalculator
        module_function

        # @param field_cultivations [Enumerable] status_completed? を持つ要素
        def progress_percent(field_cultivations:)
          list = Array(field_cultivations)
          return 0 if list.empty?

          completed = list.count { |fc| fc.status == "completed" || (fc.respond_to?(:status_completed?) && fc.status_completed?) }
          (completed.to_f / list.size * 100).round
        end
      end
    end
  end
end
