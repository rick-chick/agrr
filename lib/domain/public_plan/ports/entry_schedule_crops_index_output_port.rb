# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class EntryScheduleCropsIndexOutputPort
        def on_success(payload_hash)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
