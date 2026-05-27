# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSaveFertilizeReferenceRow
        attr_reader :reference_fertilize_id, :name, :n, :p, :k, :description, :package_size, :region

        def initialize(
          reference_fertilize_id:,
          name:,
          n: nil,
          p: nil,
          k: nil,
          description: nil,
          package_size: nil,
          region: nil
        )
          @reference_fertilize_id = reference_fertilize_id.to_i
          @name = name.nil? ? nil : name.to_s
          @n = n
          @p = p
          @k = k
          @description = description
          @package_size = package_size
          @region = region
          freeze
        end
      end
    end
  end
end
