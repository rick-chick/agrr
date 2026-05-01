# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class EntryScheduleShowOutputPort
        def on_success(success_dto)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
