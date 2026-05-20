# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # HTTP 境界: params[:moves] を adjust 用の Array<Hash> に正規化（Interactor 側に ActionController を持ち込まない）。
    module AdjustMovesFromRequest
      module_function

      # @param moves_raw [Array, ActionController::Parameters, nil]
      # @return [Array<Hash>]
      def normalize(moves_raw)
        moves = if moves_raw.is_a?(Array)
          moves_raw.map { |move| normalize_one(move) }.compact
        else
          []
        end

        moves.map do |move|
          if move[:allocation_id].present?
            move[:allocation_id] = move[:allocation_id].to_i
          end
          if move[:to_field_id].present?
            move[:to_field_id] = move[:to_field_id].to_s
          end
          move
        end
      end

      def normalize_one(move)
        case move
        when ActionController::Parameters
          move.permit!.to_h.symbolize_keys
        when Hash
          move.symbolize_keys
        when String
          begin
            JSON.parse(move).symbolize_keys
          rescue JSON::ParserError
            nil
          end
        else
          nil
        end
      end
      private_class_method :normalize_one
    end
  end
end
