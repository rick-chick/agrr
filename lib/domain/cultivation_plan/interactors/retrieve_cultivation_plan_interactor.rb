# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RetrieveCultivationPlanInteractor
        def initialize(output_port:, workbench_payload_gateway:)
          @output_port = output_port
          @workbench_payload_gateway = workbench_payload_gateway
        end

        def call(auth:, plan_id:)
          result = @workbench_payload_gateway.load_snapshot(
            auth: auth,
            plan_id: plan_id
          )

          case result[:kind]
          when :success
            @output_port.on_success(snapshot: result.fetch(:snapshot))
          when :not_found
            @output_port.on_not_found
          when :unexpected, :record_invalid
            @output_port.on_unexpected(message: result.fetch(:message))
          else
            @output_port.on_unexpected(message: "Unknown data result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
