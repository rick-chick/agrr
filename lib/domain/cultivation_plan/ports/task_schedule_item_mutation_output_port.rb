# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class TaskScheduleItemMutationOutputPort
        def on_created(item_payload)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_success(item_payload)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_record_invalid(errors:, fallback_message:)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_not_found
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_parameter_missing
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
