# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractor
        def initialize(output:, flow:)
          @output = output
          @flow = flow
        end

        def call(plan_loader:, field_name:, field_area:, daily_fixed_cost:)
          result = @flow.add_field_run(
            plan_loader: plan_loader,
            field_name: field_name,
            field_area: field_area,
            daily_fixed_cost: daily_fixed_cost
          )

          case result[:kind]
          when :success
            f = result[:plan_field]
            @output.on_success(
              field_id: f.id,
              name: f.name,
              area: f.area,
              total_area: result[:total_area]
            )
          when :not_found
            @output.on_not_found
          when :invalid_field_params
            @output.on_invalid_field_params
          when :max_fields_limit
            @output.on_max_fields_limit
          when :record_invalid
            @output.on_record_invalid(message: result.fetch(:message))
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown add_field result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
