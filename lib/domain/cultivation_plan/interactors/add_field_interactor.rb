# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AddFieldInteractor
        def initialize(output:, field_mutation_gateway:)
          @output = output
          @field_mutation_gateway = field_mutation_gateway
        end

        def call(auth:, plan_id:, field_name:, field_area:, daily_fixed_cost:)
          result = @field_mutation_gateway.add_field(
            auth: auth,
            plan_id: plan_id,
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
