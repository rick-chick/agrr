# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(output:, workbench_payload_gateway:)
          @output = output
          @workbench_payload_gateway = workbench_payload_gateway
        end

        def call(auth:, plan_id:)
          result = @workbench_payload_gateway.load_snapshot(
            auth: auth,
            plan_id: plan_id
          )

          case result[:kind]
          when :success
            body = Domain::CultivationPlan::Mappers::CultivationPlanWorkbenchPayloadMapper.to_success_body(
              result.fetch(:snapshot)
            )
            @output.on_success(body: body)
          when :not_found
            @output.on_not_found
          when :unexpected, :record_invalid
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown data result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
