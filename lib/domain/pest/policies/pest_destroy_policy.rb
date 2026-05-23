# frozen_string_literal: true

module Domain
  module Pest
    module Policies
      module PestDestroyPolicy
        module_function

        # @param usage [Domain::Pest::Dtos::PestDeleteUsage]
        # @return [Symbol, nil] :pesticides_in_use when delete must be blocked
        def blocked_reason(usage)
          return :pesticides_in_use if usage.pesticides_count.positive?

          nil
        end
      end
    end
  end
end
