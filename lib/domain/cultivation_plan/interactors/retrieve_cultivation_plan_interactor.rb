# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(output:, flow:)
          @output = output
          @flow = flow
        end

        def call(plan_loader:)
          result = @flow.data_run(plan_loader: plan_loader)

          case result[:kind]
          when :success
            @output.on_success(body: result.fetch(:body))
          when :not_found
            @output.on_not_found
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown data result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
