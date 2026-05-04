# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class ApiPlanDataInteractor
        def initialize(output:, flow: nil)
          @output = output
          @flow = flow
        end

        def call(host:, load_plan:)
          flow = @flow || Adapters::CultivationPlan::ApiCultivationPlanRestFlow.new(host)
          result = flow.data_run(load_plan: load_plan)

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
