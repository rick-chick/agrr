# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeCreateInputDto
        attr_reader :name, :n, :p, :k, :description, :package_size, :region, :is_reference

        def initialize(name:, n: nil, p: nil, k: nil, description: nil, package_size: nil, region: nil, is_reference: nil)
          @name = name
          @n = n
          @p = p
          @k = k
          @description = description
          @package_size = package_size
          @region = region
        end

        def self.from_hash(hash)
          fp = hash[:fertilize] || hash
          new(
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
