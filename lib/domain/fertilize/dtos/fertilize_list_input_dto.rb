# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeListInputDto
        attr_reader :is_admin

        def initialize(is_admin: false)
          @is_admin = is_admin
        end

        def self.from_hash(hash)
          # Rails params からは直接呼ばれないが、一貫性のために用意
          new(is_admin: hash[:is_admin] || false)
        end
      end
    end
  end
end