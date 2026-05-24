# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemUpdateInteractor
        def initialize(output_port:, gateway:, clock:, amount_unit_conversion_calculator: nil)
          @output_port = output_port
          @gateway = gateway
          @clock = clock
          @amount_unit_conversion_calculator =
            amount_unit_conversion_calculator ||
            Domain::CultivationPlan::Calculators::AmountUnitConversionCalculator.new
        end

        def call(user_id:, plan_id:, item_id:, attributes:)
          amount_snapshot = @gateway.find_item_amount_snapshot!(user_id, plan_id, item_id)
          update_attrs = Domain::CultivationPlan::Policies::TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: attributes.to_h,
            amount_snapshot: amount_snapshot,
            calculator: @amount_unit_conversion_calculator,
            rescheduled_at: @clock.now
          )
          payload = @gateway.update_item_for_plan!(user_id, plan_id, item_id, update_attrs)
          @output_port.on_success(payload)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_record_invalid(
            errors: Domain::Shared::ValidationErrorHash.from(e.errors),
            fallback_message: e.message
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
