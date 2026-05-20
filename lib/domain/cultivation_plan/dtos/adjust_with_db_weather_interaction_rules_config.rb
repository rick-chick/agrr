# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr interaction rules 配列（読み取り）。
      class AdjustWithDbWeatherInteractionRulesConfig
        attr_reader :rows

        # @param rows [Array<AdjustWithDbWeatherInteractionRuleRow>]
        def initialize(rows:)
          @rows = rows.freeze
          freeze
        end

        # @param array [Array<Hash>] AgrrInteractionRulesCalculator の戻り
        # @return [AdjustWithDbWeatherInteractionRulesConfig]
        def self.from_rules_array(array)
          rows = Array(array).map { |h| AdjustWithDbWeatherInteractionRuleRow.from_hash(h) }
          new(rows: rows)
        end

        def empty?
          rows.empty?
        end
      end
    end
  end
end
