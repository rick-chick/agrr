# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      module PublicPlanSaveInteractionRuleFilter
        CONTINUOUS_CULTIVATION_RULE_TYPE = "continuous_cultivation"

        module_function

        def continuous_cultivation?(rule_type)
          rule_type == CONTINUOUS_CULTIVATION_RULE_TYPE
        end
      end
    end
  end
end
