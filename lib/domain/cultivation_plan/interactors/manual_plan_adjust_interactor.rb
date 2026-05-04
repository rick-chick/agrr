# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class ManualPlanAdjustInteractor
        def initialize(output:, flow:)
          @output = output
          @flow = flow
        end

        def call(plan_loader:, moves_raw:)
          result = @flow.adjust_run(plan_loader: plan_loader, moves_raw: moves_raw)

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
