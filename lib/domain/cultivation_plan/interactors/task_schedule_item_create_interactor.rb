# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCreateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(plan:, attributes:)
          item = @gateway.create_item!(plan, attributes)
          @output_port.on_created(@gateway.serialize_item(item))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_record_invalid(
            errors: normalize_errors(e.errors),
            fallback_message: e.message
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end

        private

        def normalize_errors(errors)
          return errors if errors.is_a?(Hash)
          return {} unless errors.respond_to?(:to_hash)

          hash = errors.to_hash(true).transform_keys(&:to_s)
          hash.transform_values! { |messages| Array(messages).compact }
          hash
        end
      end
    end
  end
end
