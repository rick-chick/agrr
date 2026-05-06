# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class AgrrInteractionRulesCalculator
        # @param crop_groups [Hash{String => Enumerable<String>}]
        # @param random_hex [#call] -> String
        # @return [Array<Hash>]
        def self.build(crop_groups:, random_hex:)
          unless random_hex.respond_to?(:call)
            raise ArgumentError, "random_hex must respond to call"
          end

          rules = []
          crop_groups.each do |_crop_id, groups|
            Array(groups).each do |group|
              rules << {
                rule_id: "continuous_#{group}_#{random_hex.call}",
                rule_type: "continuous_cultivation",
                source_group: group,
                target_group: group,
                impact_ratio: 0.7,
                is_directional: true,
                description: "Continuous cultivation penalty for #{group}"
              }
            end
          end

          rules.uniq { |rule| [rule[:source_group], rule[:target_group]] }
        end
      end
    end
  end
end
