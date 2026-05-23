# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDeleteUsage
        attr_reader :free_crop_plans_count

        def initialize(free_crop_plans_count:)
          @free_crop_plans_count = free_crop_plans_count
        end
      end
    end
  end
end
