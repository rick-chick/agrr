# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class RemoveFieldInteractor
        def initialize(output:, flow:)
          @output = output
          @flow = flow
        end

        def call(plan_loader:, field_id_param:)
          result = @flow.remove_field_run(plan_loader: plan_loader, field_id_param: field_id_param)

          case result[:kind]
          when :success
            @output.on_success(field_id: result.fetch(:field_id), total_area: result.fetch(:total_area))
          when :not_found
            @output.on_not_found
          when :field_not_found
            @output.on_field_not_found
          when :cannot_remove_with_cultivations
            @output.on_cannot_remove_with_cultivations
          when :cannot_remove_last_field
            @output.on_cannot_remove_last_field
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown remove_field result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
