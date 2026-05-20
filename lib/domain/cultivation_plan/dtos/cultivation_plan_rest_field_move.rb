# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST adjust の移動 1 件（`AdjustMovesFromRequest.normalize` 由来）。
      class CultivationPlanRestFieldMove
        attr_reader :allocation_id, :to_field_id, :to_start_date, :to_completion_date, :extras

        # @param extras [Hash] 上記以外のキー（symbol keys）をそのまま agrr 調整入力へ渡す
        def initialize(allocation_id:, to_field_id:, to_start_date: nil, to_completion_date: nil, extras: {})
          @allocation_id = allocation_id
          @to_field_id = to_field_id
          @to_start_date = to_start_date
          @to_completion_date = to_completion_date
          @extras = extras.freeze
        end

        # @param move [Hash]
        # @return [CultivationPlanRestFieldMove]
        def self.from_normalized_hash(move)
          symbolized = Domain::Shared.symbolize_keys(move.to_hash)
          known = %i[allocation_id to_field_id to_start_date to_completion_date]
          rest = symbolized.except(*known)
          new(
            allocation_id: symbolized[:allocation_id],
            to_field_id: symbolized[:to_field_id]&.to_s,
            to_start_date: symbolized[:to_start_date],
            to_completion_date: symbolized[:to_completion_date],
            extras: rest
          )
        end

        # `AdjustWithDbWeatherInteractor` が期待する symbol key Hash（1 要素）。
        # @return [Hash]
        def to_adjust_hash
          extras.merge(allocation_id: allocation_id, to_field_id: to_field_id).tap do |h|
            h[:to_start_date] = to_start_date unless to_start_date.nil?
            h[:to_completion_date] = to_completion_date unless to_completion_date.nil?
          end
        end
      end
    end
  end
end
