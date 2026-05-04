# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(output:, workbook_payload_gateway:)
          @output = output
          @workbook_payload_gateway = workbook_payload_gateway
        end

        def call(auth:, plan_id:)
          result = @workbook_payload_gateway.build(
            auth: auth,
            plan_id: plan_id
          )

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
