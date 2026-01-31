# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeUpdateInputDto
        attr_reader :fertilize_id, :name, :n, :p, :k, :description, :package_size, :region, :is_reference

        def initialize(fertilize_id:, name: nil, n: nil, p: nil, k: nil, description: nil, package_size: nil, region: nil, is_reference: nil)
          @fertilize_id = fertilize_id
          @name = name
          @n = n
          @p = p
          @k = k
          @description = description
          @package_size = package_size
          @region = region
          @is_reference = is_reference
        end

        def self.from_hash(hash, fertilize_id)
          fp = hash[:fertilize] || hash
          new(
            fertilize_id: fertilize_id,
            name: fp[:name],
            n: fp[:n],
            p: fp[:p],
            k: fp[:k],
            description: fp[:description],
            package_size: fp[:package_size],
            region: fp[:region],
            is_reference: fp[:is_reference]
          )
        end
      end
    end
  end
end
