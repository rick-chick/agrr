# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class ManualPlanAdjustInteractor
        def initialize(output:, adjust_gateway:)
          @output = output
          @adjust_gateway = adjust_gateway
        end

        # @param moves [Array<Hash>] エッジで AdjustMovesFromRequest.normalize 済み
        def call(auth:, plan_id:, moves:)
          result = @adjust_gateway.execute(auth: auth, plan_id: plan_id, moves: moves)

          case result[:kind]
          when :crop_missing_growth_stages
            @output.on_crop_missing_growth_stages(crop_name: result.fetch(:crop_name))
          when :adjust_result
            @output.on_adjust(result: result.fetch(:adjust_hash))
          when :not_found
            @output.on_not_found
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown adjust result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
