# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemUpdateInteractor
        def initialize(output_port:, plan_gateway:, gateway:, clock:, amount_unit_conversion_calculator: nil)
          @output_port = output_port
          @plan_gateway = plan_gateway
          @gateway = gateway
          @clock = clock
          @amount_unit_conversion_calculator =
            amount_unit_conversion_calculator ||
            Domain::CultivationPlan::Calculators::AmountUnitConversionCalculator.new
        end

        def call(user_id:, plan_id:, item_id:, attributes:)
          unless TaskSchedulePrivatePlanAccess.access_allowed?(
            plan_gateway: @plan_gateway, plan_id: plan_id, user_id: user_id
          )
            @output_port.on_not_found
            return
          end

          amount_snapshot = @gateway.find_item_amount_snapshot!(plan_id, item_id)
          update_attrs = Domain::CultivationPlan::Policies::TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: attributes.to_h,
            amount_snapshot: amount_snapshot,
            calculator: @amount_unit_conversion_calculator,
            rescheduled_at: @clock.now
          )
          payload = @gateway.update_item_for_plan!(plan_id, item_id, update_attrs)
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
