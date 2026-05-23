# frozen_string_literal: true

module Domain
  module Farm
    module Policies
      module FarmDestroyPolicy
        module_function

        # @param usage [Domain::Farm::Dtos::FarmDeleteUsage]
        # @return [Symbol, nil] :free_crop_plans when delete must be blocked
        def blocked_reason(usage)
          return :free_crop_plans if usage.free_crop_plans_count.positive?

          nil
        end
      end
    end
  end
end
