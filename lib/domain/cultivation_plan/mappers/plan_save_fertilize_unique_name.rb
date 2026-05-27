# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveFertilizeUniqueName
        # @yieldparam candidate [String]
        def self.each_candidate(base_name, &block)
          block.call("#{base_name} (コピー)")
          suffix = 2
          loop do
            block.call("#{base_name} (コピー #{suffix})")
            suffix += 1
          end
        end
      end
    end
  end
end
