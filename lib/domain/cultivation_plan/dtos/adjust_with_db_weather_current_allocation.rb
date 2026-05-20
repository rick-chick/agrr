# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # adjust_with_db_weather 用「現在の割当」読み取りモデル（agrr 入力互換 Hash から組み立て）。
      class AdjustWithDbWeatherCurrentAllocation
        attr_reader :optimization_result

        # @param optimization_result [AdjustWithDbWeatherOptimizationResultSnapshot, nil]
        def initialize(optimization_result:)
          @optimization_result = optimization_result
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherCurrentAllocation]
        def self.from_allocation_hash(h)
          return empty if h.nil? || h == {}

          sym = Domain::Shared.symbolize_keys(h.to_hash)
          opt = sym[:optimization_result]
          return empty if opt.nil?

          new(optimization_result: AdjustWithDbWeatherOptimizationResultSnapshot.from_hash(opt))
        end

        def self.empty
          new(optimization_result: nil)
        end
      end
    end
  end
end
