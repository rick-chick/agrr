# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanCreateNoCropsFailureInput
        attr_reader :farm_id, :farm_size_id, :region, :farm_sizes

        def initialize(farm_id:, farm_size_id:, region:, farm_sizes:)
          @farm_id = farm_id
          @farm_size_id = farm_size_id
          @region = region
          @farm_sizes = farm_sizes
        end
      end
    end
  end
end
